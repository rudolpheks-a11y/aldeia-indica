package service

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	EventProfileView      = "profile_view"
	EventContactInitiated = "contact_initiated"
)

type AnalyticsService struct {
	db *pgxpool.Pool
}

func NewAnalyticsService(db *pgxpool.Pool) *AnalyticsService {
	return &AnalyticsService{db: db}
}

func (s *AnalyticsService) RecordEvent(ctx context.Context, communityID, providerID uuid.UUID, actorID *uuid.UUID, eventType string) {
	// Os chamadores rodam isto em `go RecordEvent(r.Context(), ...)` — mas o
	// contexto da request é cancelado assim que o handler retorna, então a
	// goroutine perdia a corrida e o INSERT era abortado silenciosamente
	// (o erro já era ignorado). Desacopla do cancelamento da request e dá um
	// deadline próprio pra não vazar goroutine se o banco travar.
	bg, cancel := context.WithTimeout(context.WithoutCancel(ctx), 5*time.Second)
	defer cancel()
	// Fire-and-forget: analytics failures must not block the main flow.
	_, _ = s.db.Exec(bg,
		`INSERT INTO provider_events (community_id, provider_id, actor_id, event_type)
		 VALUES ($1, $2, $3, $4)`,
		communityID, providerID, actorID, eventType,
	)
}

type DashboardStats struct {
	ScoreAldeia     float64 `json:"score_aldeia"`
	AvgRating       float64 `json:"avg_rating"`
	ViewCount30d    int     `json:"view_count_30d"`
	ContactCount30d int     `json:"contact_count_30d"`
	CategoryRank    *int    `json:"category_rank,omitempty"`
	TotalInCategory *int    `json:"total_in_category,omitempty"`
}

func (s *AnalyticsService) DashboardSummary(ctx context.Context, communityID, providerID uuid.UUID) (*DashboardStats, error) {
	stats := &DashboardStats{}
	err := s.db.QueryRow(ctx,
		`SELECT COALESCE(score_aldeia, 0), COALESCE(avg_rating, 0)
		 FROM provider_profiles WHERE user_id = $1 AND community_id = $2`,
		providerID, communityID,
	).Scan(&stats.ScoreAldeia, &stats.AvgRating)
	if err != nil {
		return nil, err
	}

	since := time.Now().AddDate(0, 0, -30)
	rows, err := s.db.Query(ctx,
		`SELECT event_type, COUNT(*) FROM provider_events
		 WHERE provider_id = $1 AND occurred_at >= $2
		 GROUP BY event_type`,
		providerID, since,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var evType string
		var count int
		if err := rows.Scan(&evType, &count); err != nil {
			return nil, err
		}
		switch evType {
		case EventProfileView:
			stats.ViewCount30d = count
		case EventContactInitiated:
			stats.ContactCount30d = count
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// Category rank: position of this provider sorted by score within their primary category
	var rank, total int
	err = s.db.QueryRow(ctx, `
		WITH ranked AS (
		    SELECT ps.provider_id,
		           RANK() OVER (ORDER BY pp.score_aldeia DESC) AS rnk,
		           COUNT(*) OVER () AS total
		    FROM provider_services ps
		    JOIN provider_profiles pp ON pp.user_id = ps.provider_id
		    JOIN users u ON u.id = pp.user_id
		    WHERE ps.community_id = $1
		      AND ps.category_id = (
		            SELECT category_id FROM provider_services
		            WHERE provider_id = $2
		            LIMIT 1
		          )
		      AND pp.is_visible = true
		      AND u.status = 'active'
		)
		SELECT rnk, total FROM ranked WHERE provider_id = $2
	`, communityID, providerID).Scan(&rank, &total)
	if err == nil {
		stats.CategoryRank = &rank
		stats.TotalInCategory = &total
	}

	return stats, nil
}
