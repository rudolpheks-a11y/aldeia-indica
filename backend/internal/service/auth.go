package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/auth"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/domain"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/email"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidCredentials  = errors.New("invalid email or password")
	ErrUserPending         = errors.New("account pending approval")
	ErrUserSuspended       = errors.New("account suspended")
	ErrInvalidResetCode    = errors.New("invalid or expired reset code")
)

type AuthService struct {
	db            *pgxpool.Pool
	jwt           *auth.JWT
	refreshExpiry time.Duration
	email         *email.Client
}

func NewAuthService(db *pgxpool.Pool, j *auth.JWT, refreshExpiry time.Duration, emailClient *email.Client) *AuthService {
	return &AuthService{db: db, jwt: j, refreshExpiry: refreshExpiry, email: emailClient}
}

type RegisterMoradorInput struct {
	CommunityID       uuid.UUID
	Email             string
	Password          string
	FullName          string
	StreetAddress     string
	HouseNumber       string
	NeighborhoodBlock string
}

type RegisterPrestadorInput struct {
	CommunityID         uuid.UUID
	Email               string
	Password            string
	FullName            string
	City                string
	YearsInNeighborhood int
	ProfessionalBio     string
}

type TokenPair struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	UserID       string    `json:"user_id"`
}

func (s *AuthService) RegisterMorador(ctx context.Context, in RegisterMoradorInput) (uuid.UUID, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
	if err != nil {
		return uuid.Nil, fmt.Errorf("hash password: %w", err)
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return uuid.Nil, err
	}
	defer tx.Rollback(ctx)

	var userID uuid.UUID
	err = tx.QueryRow(ctx,
		`INSERT INTO users (community_id, email, password_hash, role, status, full_name)
		 VALUES ($1, $2, $3, 'morador', 'pending', $4) RETURNING id`,
		in.CommunityID, in.Email, string(hash), in.FullName,
	).Scan(&userID)
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert user: %w", err)
	}

	_, err = tx.Exec(ctx,
		`INSERT INTO morador_profiles (user_id, community_id, street_address, house_number, neighborhood_block)
		 VALUES ($1, $2, $3, $4, $5)`,
		userID, in.CommunityID, in.StreetAddress, in.HouseNumber, in.NeighborhoodBlock,
	)
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert morador profile: %w", err)
	}

	_, err = tx.Exec(ctx,
		`INSERT INTO user_approvals (community_id, applicant_id) VALUES ($1, $2)`,
		in.CommunityID, userID,
	)
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert approval: %w", err)
	}

	return userID, tx.Commit(ctx)
}

func (s *AuthService) RegisterPrestador(ctx context.Context, in RegisterPrestadorInput) (uuid.UUID, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(in.Password), bcrypt.DefaultCost)
	if err != nil {
		return uuid.Nil, fmt.Errorf("hash password: %w", err)
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return uuid.Nil, err
	}
	defer tx.Rollback(ctx)

	var userID uuid.UUID
	err = tx.QueryRow(ctx,
		`INSERT INTO users (community_id, email, password_hash, role, status, full_name)
		 VALUES ($1, $2, $3, 'prestador', 'pending', $4) RETURNING id`,
		in.CommunityID, in.Email, string(hash), in.FullName,
	).Scan(&userID)
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert user: %w", err)
	}

	_, err = tx.Exec(ctx,
		`INSERT INTO provider_profiles (user_id, community_id, city, years_in_neighborhood, professional_bio)
		 VALUES ($1, $2, $3, $4, $5)`,
		userID, in.CommunityID, in.City, in.YearsInNeighborhood, in.ProfessionalBio,
	)
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert provider profile: %w", err)
	}

	return userID, tx.Commit(ctx)
}

type LoginInput struct {
	CommunityID uuid.UUID
	Email       string
	Password    string
	DeviceInfo  string
	Platform    string
}

func (s *AuthService) Login(ctx context.Context, in LoginInput) (*TokenPair, error) {
	var user struct {
		ID           uuid.UUID
		PasswordHash string
		Role         domain.UserRole
		Status       domain.UserStatus
	}
	err := s.db.QueryRow(ctx,
		`SELECT id, password_hash, role, status FROM users
		 WHERE community_id = $1 AND email = $2`,
		in.CommunityID, in.Email,
	).Scan(&user.ID, &user.PasswordHash, &user.Role, &user.Status)
	if err != nil {
		return nil, ErrInvalidCredentials
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(in.Password)); err != nil {
		return nil, ErrInvalidCredentials
	}

	switch user.Status {
	case domain.StatusPending:
		return nil, ErrUserPending
	case domain.StatusSuspended:
		return nil, ErrUserSuspended
	}

	return s.issuePair(ctx, domain.Claims{
		UserID:      user.ID,
		CommunityID: in.CommunityID,
		Role:        user.Role,
	}, in.DeviceInfo)
}

func (s *AuthService) Refresh(ctx context.Context, rawToken string) (*TokenPair, error) {
	hash := tokenHash(rawToken)

	var rt struct {
		ID          uuid.UUID
		UserID      uuid.UUID
		CommunityID uuid.UUID
		Role        domain.UserRole
		ExpiresAt   time.Time
		RevokedAt   *time.Time
	}
	err := s.db.QueryRow(ctx,
		`SELECT rt.id, rt.user_id, u.community_id, u.role, rt.expires_at, rt.revoked_at
		 FROM refresh_tokens rt JOIN users u ON u.id = rt.user_id
		 WHERE rt.token_hash = $1`,
		hash,
	).Scan(&rt.ID, &rt.UserID, &rt.CommunityID, &rt.Role, &rt.ExpiresAt, &rt.RevokedAt)
	if err != nil {
		return nil, errors.New("invalid refresh token")
	}
	if rt.RevokedAt != nil {
		// Reuse of an already-rotated token is a theft signal: someone else
		// already redeemed this token. Kill every other refresh token for
		// this user so the legitimate session (and the attacker's) both
		// have to log in again, instead of only the attacker staying valid.
		_, _ = s.db.Exec(ctx,
			`UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`,
			rt.UserID,
		)
		return nil, errors.New("refresh token expired or revoked")
	}
	if rt.ExpiresAt.Before(time.Now()) {
		return nil, errors.New("refresh token expired or revoked")
	}

	_, err = s.db.Exec(ctx,
		`UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1`, rt.ID)
	if err != nil {
		return nil, err
	}

	return s.issuePair(ctx, domain.Claims{
		UserID:      rt.UserID,
		CommunityID: rt.CommunityID,
		Role:        rt.Role,
	}, "")
}

func (s *AuthService) Logout(ctx context.Context, rawToken string) error {
	hash := tokenHash(rawToken)
	_, err := s.db.Exec(ctx,
		`UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = $1`, hash)
	return err
}

func (s *AuthService) issuePair(ctx context.Context, claims domain.Claims, deviceInfo string) (*TokenPair, error) {
	access, err := s.jwt.IssueAccess(claims)
	if err != nil {
		return nil, err
	}

	raw := make([]byte, 48)
	if _, err := rand.Read(raw); err != nil {
		return nil, err
	}
	rawRefresh := base64.URLEncoding.EncodeToString(raw)
	hash := tokenHash(rawRefresh)

	_, err = s.db.Exec(ctx,
		`INSERT INTO refresh_tokens (user_id, token_hash, device_info, expires_at)
		 VALUES ($1, $2, $3, $4)`,
		claims.UserID, hash, deviceInfo, time.Now().Add(s.refreshExpiry),
	)
	if err != nil {
		return nil, err
	}

	return &TokenPair{AccessToken: access, RefreshToken: rawRefresh, UserID: claims.UserID.String()}, nil
}

func tokenHash(raw string) string {
	h := sha256.Sum256([]byte(raw))
	return base64.URLEncoding.EncodeToString(h[:])
}

func (s *AuthService) RequestPasswordReset(ctx context.Context, communityID uuid.UUID, emailAddr string) error {
	var userID uuid.UUID
	err := s.db.QueryRow(ctx,
		`SELECT id FROM users WHERE community_id = $1 AND email = $2`,
		communityID, emailAddr,
	).Scan(&userID)
	if err != nil {
		// Don't reveal whether the email exists
		return nil
	}

	code, err := generateResetCode()
	if err != nil {
		return fmt.Errorf("generate code: %w", err)
	}
	hash := codeHash(code)

	_, err = s.db.Exec(ctx,
		`INSERT INTO password_reset_tokens (user_id, code_hash, expires_at)
		 VALUES ($1, $2, $3)`,
		userID, hash, time.Now().Add(30*time.Minute),
	)
	if err != nil {
		return fmt.Errorf("store reset token: %w", err)
	}

	return s.email.Send(ctx, email.Message{
		To:      emailAddr,
		Subject: "Código de recuperação de senha — Aldeia Indica",
		HTML:    resetEmailHTML(code),
	})
}

func (s *AuthService) ResetPassword(ctx context.Context, communityID uuid.UUID, emailAddr, code, newPassword string) error {
	var userID uuid.UUID
	err := s.db.QueryRow(ctx,
		`SELECT id FROM users WHERE community_id = $1 AND email = $2`,
		communityID, emailAddr,
	).Scan(&userID)
	if err != nil {
		return ErrInvalidResetCode
	}

	hash := codeHash(code)
	var tokenID uuid.UUID
	err = s.db.QueryRow(ctx,
		`SELECT id FROM password_reset_tokens
		 WHERE user_id = $1 AND code_hash = $2 AND used_at IS NULL AND expires_at > now()`,
		userID, hash,
	).Scan(&tokenID)
	if err != nil {
		return ErrInvalidResetCode
	}

	newHash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("hash password: %w", err)
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx,
		`UPDATE users SET password_hash = $1 WHERE id = $2`,
		string(newHash), userID,
	)
	if err != nil {
		return fmt.Errorf("update password: %w", err)
	}

	_, err = tx.Exec(ctx,
		`UPDATE password_reset_tokens SET used_at = now() WHERE user_id = $1`,
		userID,
	)
	if err != nil {
		return fmt.Errorf("invalidate tokens: %w", err)
	}

	return tx.Commit(ctx)
}

func generateResetCode() (string, error) {
	max := big.NewInt(1_000_000)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

func codeHash(code string) string {
	h := sha256.Sum256([]byte(code))
	return base64.URLEncoding.EncodeToString(h[:])
}

func resetEmailHTML(code string) string {
	return fmt.Sprintf(`<!DOCTYPE html>
<html>
<body style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px">
  <h2 style="color:#2E5C74">Aldeia Indica</h2>
  <p>Você solicitou a recuperação da sua senha.</p>
  <p>Seu código de recuperação é:</p>
  <p style="font-size:36px;font-weight:bold;letter-spacing:8px;color:#2E5C74;margin:24px 0">%s</p>
  <p>Digite esse código no app para criar uma nova senha.<br>
  O código expira em <strong>30 minutos</strong>.</p>
  <p style="color:#999;font-size:12px">Se você não solicitou isso, ignore este e-mail.</p>
</body>
</html>`, code)
}
