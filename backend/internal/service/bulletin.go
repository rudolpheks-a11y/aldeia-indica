package service

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type BulletinService struct {
	db *pgxpool.Pool
}

func NewBulletinService(db *pgxpool.Pool) *BulletinService {
	return &BulletinService{db: db}
}

type BulletinPost struct {
	ID         uuid.UUID  `json:"id"`
	AuthorName string     `json:"author_name"`
	Content    string     `json:"content"`
	Status     string     `json:"status"`
	CreatedAt  time.Time  `json:"created_at"`
	ApprovedAt *time.Time `json:"approved_at,omitempty"`
}

var ErrBulletinNotFound = errors.New("bulletin post not found")

func (s *BulletinService) Create(ctx context.Context, communityID, authorID uuid.UUID, content string) error {
	_, err := s.db.Exec(ctx,
		`INSERT INTO bulletin_posts (community_id, author_id, content) VALUES ($1,$2,$3)`,
		communityID, authorID, content,
	)
	return err
}

func (s *BulletinService) ListApproved(ctx context.Context, communityID uuid.UUID) ([]BulletinPost, error) {
	rows, err := s.db.Query(ctx,
		`SELECT bp.id, u.full_name, bp.content, bp.status, bp.created_at, bp.approved_at
		 FROM bulletin_posts bp
		 JOIN users u ON u.id = bp.author_id
		 WHERE bp.community_id=$1 AND bp.status='approved'
		 ORDER BY bp.approved_at DESC
		 LIMIT 50`,
		communityID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []BulletinPost
	for rows.Next() {
		var p BulletinPost
		if err := rows.Scan(&p.ID, &p.AuthorName, &p.Content, &p.Status, &p.CreatedAt, &p.ApprovedAt); err != nil {
			return nil, err
		}
		posts = append(posts, p)
	}
	return posts, rows.Err()
}

func (s *BulletinService) ListPending(ctx context.Context, communityID uuid.UUID) ([]BulletinPost, error) {
	rows, err := s.db.Query(ctx,
		`SELECT bp.id, u.full_name, bp.content, bp.status, bp.created_at, bp.approved_at
		 FROM bulletin_posts bp
		 JOIN users u ON u.id = bp.author_id
		 WHERE bp.community_id=$1 AND bp.status='pending'
		 ORDER BY bp.created_at ASC`,
		communityID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []BulletinPost
	for rows.Next() {
		var p BulletinPost
		if err := rows.Scan(&p.ID, &p.AuthorName, &p.Content, &p.Status, &p.CreatedAt, &p.ApprovedAt); err != nil {
			return nil, err
		}
		posts = append(posts, p)
	}
	return posts, rows.Err()
}

func (s *BulletinService) Review(ctx context.Context, communityID, postID, adminID uuid.UUID, approve bool) error {
	status := "rejected"
	if approve {
		status = "approved"
	}
	tag, err := s.db.Exec(ctx,
		`UPDATE bulletin_posts
		 SET status=$1, approved_by=$2, approved_at=now()
		 WHERE id=$3 AND community_id=$4 AND status='pending'`,
		status, adminID, postID, communityID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrBulletinNotFound
	}
	return nil
}
