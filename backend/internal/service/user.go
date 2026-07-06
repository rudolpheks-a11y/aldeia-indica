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
	ErrInvalidInvite = errors.New("invalid or expired invite")
	ErrOnlyResidents = errors.New("only residents can create invites")
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
