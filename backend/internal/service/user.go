package service

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrInsufficientVotes = errors.New("need 2 votes to approve")
	ErrAlreadyVoted      = errors.New("already voted for this applicant")
	ErrInvalidInvite     = errors.New("invalid or expired invite")
)

type UserService struct {
	db *pgxpool.Pool
}

func NewUserService(db *pgxpool.Pool) *UserService {
	return &UserService{db: db}
}

type PendingApplicant struct {
	UserID    uuid.UUID
	FullName  string
	Email     string
	Address   string
	VoteCount int
	CreatedAt time.Time
}

func (s *UserService) ListPending(ctx context.Context, communityID uuid.UUID) ([]PendingApplicant, error) {
	rows, err := s.db.Query(ctx,
		`SELECT u.id, u.full_name, u.email, mp.street_address,
		        COUNT(av.id) AS vote_count, ua.created_at
		 FROM user_approvals ua
		 JOIN users u ON u.id = ua.applicant_id
		 JOIN morador_profiles mp ON mp.user_id = u.id
		 LEFT JOIN approval_votes av ON av.approval_id = ua.id
		 WHERE ua.community_id = $1 AND ua.status = 'pending'
		 GROUP BY u.id, u.full_name, u.email, mp.street_address, ua.created_at
		 ORDER BY ua.created_at ASC`,
		communityID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []PendingApplicant
	for rows.Next() {
		var p PendingApplicant
		if err := rows.Scan(&p.UserID, &p.FullName, &p.Email, &p.Address, &p.VoteCount, &p.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, p)
	}
	return result, rows.Err()
}

func (s *UserService) Vote(ctx context.Context, voterID, communityID uuid.UUID, approvalID uuid.UUID) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx,
		`INSERT INTO approval_votes (approval_id, voter_id, community_id) VALUES ($1, $2, $3)`,
		approvalID, voterID, communityID,
	)
	if err != nil {
		return ErrAlreadyVoted
	}

	var voteCount int
	err = tx.QueryRow(ctx,
		`SELECT COUNT(*) FROM approval_votes WHERE approval_id = $1`, approvalID,
	).Scan(&voteCount)
	if err != nil {
		return err
	}

	if voteCount >= 2 {
		var applicantID uuid.UUID
		err = tx.QueryRow(ctx,
			`UPDATE user_approvals SET status = 'approved', method = 'resident_vote', resolved_at = now()
			 WHERE id = $1 RETURNING applicant_id`, approvalID,
		).Scan(&applicantID)
		if err != nil {
			return err
		}
		_, err = tx.Exec(ctx,
			`UPDATE users SET status = 'active' WHERE id = $1`, applicantID)
		if err != nil {
			return err
		}
		_, err = tx.Exec(ctx,
			`UPDATE morador_profiles SET verified_resident = true WHERE user_id = $1`, applicantID)
		if err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}

func (s *UserService) AdminResolve(ctx context.Context, adminID, communityID, approvalID uuid.UUID, approve bool) error {
	status := "approved"
	if !approve {
		status = "rejected"
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var applicantID uuid.UUID
	err = tx.QueryRow(ctx,
		`UPDATE user_approvals SET status = $1, method = 'admin', resolved_by = $2, resolved_at = now()
		 WHERE id = $3 AND community_id = $4 RETURNING applicant_id`,
		status, adminID, approvalID, communityID,
	).Scan(&applicantID)
	if err != nil {
		return fmt.Errorf("resolve approval: %w", err)
	}

	if approve {
		_, err = tx.Exec(ctx, `UPDATE users SET status = 'active' WHERE id = $1`, applicantID)
		if err != nil {
			return err
		}
		_, err = tx.Exec(ctx, `UPDATE morador_profiles SET verified_resident = true WHERE user_id = $1`, applicantID)
		if err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}

func (s *UserService) CreateInvite(ctx context.Context, creatorID, communityID uuid.UUID, intendedEmail string) (string, error) {
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

func (s *UserService) UseInvite(ctx context.Context, token string, userID uuid.UUID) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var inviteID uuid.UUID
	err = tx.QueryRow(ctx,
		`UPDATE invites SET used_by = $1, used_at = now()
		 WHERE token = $2 AND used_at IS NULL AND expires_at > now()
		 RETURNING id`,
		userID, token,
	).Scan(&inviteID)
	if err != nil {
		return ErrInvalidInvite
	}

	_, err = tx.Exec(ctx, `UPDATE users SET status = 'active' WHERE id = $1`, userID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `UPDATE morador_profiles SET verified_resident = true WHERE user_id = $1`, userID)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}
