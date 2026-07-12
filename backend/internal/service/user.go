package service

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/domain"
)

var (
	ErrInvalidInvite    = errors.New("invalid or expired invite")
	ErrOnlyResidents    = errors.New("only residents can create invites")
	ErrUserNotFound     = errors.New("user not found")
	ErrCannotDeleteSelf = errors.New("admin cannot delete their own account this way")
)

type UserService struct {
	db *pgxpool.Pool
}

func NewUserService(db *pgxpool.Pool) *UserService {
	return &UserService{db: db}
}

// CreateInvite gera um código de convite — só moradores convidam moradores
// (candidato precisa de 2 códigos de moradores diferentes pra se cadastrar,
// ver AuthService.RegisterMorador). Consumido no próprio cadastro, não
// exige o convidado estar autenticado.
func (s *UserService) CreateInvite(ctx context.Context, creatorID, communityID uuid.UUID, creatorRole domain.UserRole, intendedEmail string) (string, error) {
	if creatorRole != domain.RoleMorador {
		return "", ErrOnlyResidents
	}

	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	token := base64.URLEncoding.EncodeToString(raw)

	_, err := s.db.Exec(ctx,
		`INSERT INTO invites (community_id, created_by, token, intended_email, expires_at)
		 VALUES ($1, $2, $3, $4, $5)`,
		communityID, creatorID, token, intendedEmail, time.Now().Add(72*time.Hour),
	)
	if err != nil {
		return "", err
	}
	return token, nil
}

func (s *UserService) ValidateInvite(ctx context.Context, token string) (uuid.UUID, error) {
	var communityID uuid.UUID
	err := s.db.QueryRow(ctx,
		`SELECT community_id FROM invites
		 WHERE token = $1 AND used_at IS NULL AND expires_at > now()`,
		token,
	).Scan(&communityID)
	if err != nil {
		return uuid.Nil, ErrInvalidInvite
	}
	return communityID, nil
}

// DeleteAccount marca a conta como excluída. **Nada é apagado nem
// anonimizado** — e isso é deliberado, por duas razões:
//
//  1. Antifraude: o e-mail continua preso a esta conta. Um prestador não pode
//     se recadastrar com o mesmo e-mail para nascer limpo e fugir de uma
//     avaliação ruim; ele só consegue reativar a conta antiga, com o histórico
//     de avaliações junto.
//  2. Integridade: as avaliações e indicações que a pessoa deu a terceiros
//     sustentam o Score Aldeia deles. Apagar mudaria a nota de quem ficou (as
//     FKs são RESTRICT — o Postgres nem permitiria o DELETE).
//
// deletedBy diz quem excluiu: se foi o próprio usuário, ele reativa sozinho no
// login. Se foi um admin, não — senão banir um fraudador seria inútil.
func (s *UserService) DeleteAccount(ctx context.Context, userID, deletedBy uuid.UUID) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	tag, err := tx.Exec(ctx,
		`UPDATE users
		    SET deleted_at = now(), deleted_by = $2, updated_at = now()
		  WHERE id = $1 AND deleted_at IS NULL`,
		userID, deletedBy,
	)
	if err != nil {
		return err
	}
	// Já excluída (ou inexistente): 404 em vez de fingir sucesso.
	if tag.RowsAffected() == 0 {
		return ErrUserNotFound
	}

	// Sem isso, o refresh token ainda vivo emitiria um novo access token e a
	// conta excluída continuaria navegando até o access token expirar.
	if _, err := tx.Exec(ctx,
		`UPDATE refresh_tokens SET revoked_at = now()
		  WHERE user_id = $1 AND revoked_at IS NULL`, userID); err != nil {
		return err
	}

	return tx.Commit(ctx)
}

// Reactivate traz a conta de volta com todo o histórico. Só vale para quem se
// autoexcluiu — conta removida por um admin não volta pelas mãos do dono.
func (s *UserService) Reactivate(ctx context.Context, userID uuid.UUID) error {
	tag, err := s.db.Exec(ctx,
		`UPDATE users SET deleted_at = NULL, deleted_by = NULL, updated_at = now()
		  WHERE id = $1 AND deleted_at IS NOT NULL`,
		userID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrUserNotFound
	}
	return nil
}

// DeleteAccountAsAdmin exclui a conta de um morador ou prestador da própria
// comunidade do admin. Um admin nunca exclui outro admin por aqui — remoção de
// moderador é operação de banco, deliberadamente fora do app.
func (s *UserService) DeleteAccountAsAdmin(ctx context.Context, targetID, communityID, adminID uuid.UUID) error {
	var role domain.UserRole
	err := s.db.QueryRow(ctx,
		`SELECT role FROM users
		  WHERE id = $1 AND community_id = $2 AND deleted_at IS NULL`,
		targetID, communityID,
	).Scan(&role)
	if err != nil {
		return ErrUserNotFound
	}
	if role == domain.RoleAdmin {
		return ErrCannotDeleteSelf
	}
	return s.DeleteAccount(ctx, targetID, adminID)
}
