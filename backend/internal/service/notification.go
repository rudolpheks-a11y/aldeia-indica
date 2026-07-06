package service

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type NotificationService struct {
	db *pgxpool.Pool
}

func NewNotificationService(db *pgxpool.Pool) *NotificationService {
	return &NotificationService{db: db}
}

// Create é chamado a partir de outros services (rating, recommendation,
// request) depois que a ação principal já foi persistida — é sempre
// best-effort: os chamadores ignoram o erro de propósito, porque uma
// avaliação/indicação/resposta enviada com sucesso não pode falhar só
// porque a notificação falhou.
func (s *NotificationService) Create(ctx context.Context, communityID, userID uuid.UUID, notifType, title, body string, relatedID *uuid.UUID) error {
	_, err := s.db.Exec(ctx,
		`INSERT INTO notifications (community_id, user_id, type, title, body, related_id)
		 VALUES ($1,$2,$3,$4,$5,$6)`,
		communityID, userID, notifType, title, body, relatedID,
	)
	return err
}

type NotificationRow struct {
	ID        uuid.UUID  `json:"id"`
	Type      string     `json:"type"`
	Title     string     `json:"title"`
	Body      string     `json:"body"`
	RelatedID *uuid.UUID `json:"related_id"`
	Read      bool       `json:"read"`
	CreatedAt time.Time  `json:"created_at"`
}

func (s *NotificationService) List(ctx context.Context, userID uuid.UUID, limit int) ([]NotificationRow, error) {
	if limit == 0 {
		limit = 50
	}
	rows, err := s.db.Query(ctx,
		`SELECT id, type, title, body, related_id, (read_at IS NOT NULL), created_at
		 FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT $2`,
		userID, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []NotificationRow
	for rows.Next() {
		var row NotificationRow
		if err := rows.Scan(&row.ID, &row.Type, &row.Title, &row.Body, &row.RelatedID, &row.Read, &row.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, row)
	}
	return result, rows.Err()
}

func (s *NotificationService) UnreadCount(ctx context.Context, userID uuid.UUID) (int, error) {
	var count int
	err := s.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id=$1 AND read_at IS NULL`,
		userID,
	).Scan(&count)
	return count, err
}

func (s *NotificationService) MarkAllRead(ctx context.Context, userID uuid.UUID) error {
	_, err := s.db.Exec(ctx,
		`UPDATE notifications SET read_at=now() WHERE user_id=$1 AND read_at IS NULL`,
		userID,
	)
	return err
}
