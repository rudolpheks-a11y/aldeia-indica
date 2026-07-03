package service

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	EventProfileView       = "profile_view"
	EventContactInitiated  = "contact_initiated"
	EventHireCompleted     = "hire_completed"
)

type AnalyticsService struct {
	db *pgxpool.Pool
}

func NewAnalyticsService(db *pgxpool.Pool) *AnalyticsService {
	return &AnalyticsService{db: db}
}

func (s *AnalyticsService) RecordEvent(ctx context.Context, communityID, providerID uuid.UUID, actorID *uuid.UUID, eventType string) {
	// Fire-and-forget: analytics failures must not block the main flow.
	_, _ = s.db.Exec(ctx,
		`INSERT INTO provider_events (community_id, provider_id, actor_id, event_type)
		 VALUES ($1, $2, $3, $4)`,
		communityID, providerID, actorID, eventType,
	)
}

type DashboardStats struct {
	ScoreAldeia      float64 `json:"score_aldeia"`
	AvgRating        float64 `json:"avg_rating"`
	TotalHires       int     `json:"total_hires"`
	ViewCount30d     int     `json:"view_count_30d"`
	ContactCount30d  int     `json:"contact_count_30d"`
	HireCount30d     int     `json:"hire_count_30d"`
	CategoryRank     *int    `json:"category_rank,omitempty"`
	TotalInCategory  *int    `json:"total_in_category,omitempty"`
}

func (s *AnalyticsService) DashboardSummary(ctx context.Context, communityID, providerID uuid.UUID) (*DashboardStats, error) {
	stats := &DashboardStats{}
	err := s.db.QueryRow(ctx,
		`SELECT COALESCE(score_aldeia, 0), COALESCE(avg_rating, 0), total_hires
		 FROM provider_profiles WHERE user_id = $1 AND community_id = $2`,
		providerID, communityID,
	).Scan(&stats.ScoreAldeia, &stats.AvgRating, &stats.TotalHires)
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
		rows.Scan(&evType, &count)
		switch evType {
		case EventProfileView:
			stats.ViewCount30d = count
		case EventContactInitiated:
			stats.ContactCount30d = count
		case EventHireCompleted:
			stats.HireCount30d = count
		}
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
		    WHERE ps.community_id = $1
		      AND ps.category_id = (
		            SELECT category_id FROM provider_services
		            WHERE provider_id = $2
		            LIMIT 1
		          )
		      AND pp.is_visible = true
		)
		SELECT rnk, total FROM ranked WHERE provider_id = $2
	`, communityID, providerID).Scan(&rank, &total)
	if err == nil {
		stats.CategoryRank = &rank
		stats.TotalInCategory = &total
	}

	return stats, nil
}

var ErrAlreadyHired = errors.New("you have already confirmed hiring this provider")

// HireCompleted registers a hire (one per hirer per provider — same
// uniqueness semantics as ratings/recommendations), increments total_hires,
// logs the event, and triggers score recompute. A repeat call from the same
// hirer is a no-op (ErrAlreadyHired), not a repeated increment.
func (s *AnalyticsService) HireCompleted(ctx context.Context, communityID, providerID, actorID uuid.UUID, providerSvc *ProviderService) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	tag, err := tx.Exec(ctx,
		`INSERT INTO provider_hires (community_id, provider_id, hirer_id)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (community_id, provider_id, hirer_id) DO NOTHING`,
		communityID, providerID, actorID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrAlreadyHired
	}

	_, err = tx.Exec(ctx,
		`UPDATE provider_profiles SET total_hires = total_hires + 1
		 WHERE user_id = $1 AND community_id = $2`,
		providerID, communityID,
	)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx,
		`INSERT INTO provider_events (community_id, provider_id, actor_id, event_type)
		 VALUES ($1, $2, $3, $4)`,
		communityID, providerID, actorID, EventHireCompleted,
	)
	if err != nil {
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return err
	}

	// Recompute score after commit (non-transactional, best-effort)
	return providerSvc.RecomputeScore(ctx, providerID)
}
