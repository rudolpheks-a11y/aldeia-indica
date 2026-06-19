package service

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type RecommendationService struct {
	db          *pgxpool.Pool
	providerSvc *ProviderService
}

func NewRecommendationService(db *pgxpool.Pool, providerSvc *ProviderService) *RecommendationService {
	return &RecommendationService{db: db, providerSvc: providerSvc}
}

type Recommender struct {
	UserID    uuid.UUID `json:"user_id"`
	FullName  string    `json:"full_name"`
	AvatarKey *string   `json:"avatar_key"`
	CreatedAt time.Time `json:"created_at"`
}

func (s *RecommendationService) Create(ctx context.Context, communityID, providerID, recommenderID uuid.UUID) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx,
		`INSERT INTO recommendations (community_id, provider_id, recommender_id) VALUES ($1,$2,$3)`,
		communityID, providerID, recommenderID,
	)
	if err != nil {
		return err
	}

	_, err = tx.Exec(ctx,
		`UPDATE provider_profiles SET recommendation_count = recommendation_count + 1
		 WHERE user_id=$1 AND community_id=$2`,
		providerID, communityID,
	)
	if err != nil {
		return err
	}

	if err := tx.Commit(ctx); err != nil {
		return err
	}

	return s.providerSvc.RecomputeScore(ctx, providerID)
}

func (s *RecommendationService) Delete(ctx context.Context, communityID, providerID, recommenderID uuid.UUID) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx,
		`DELETE FROM recommendations WHERE community_id=$1 AND provider_id=$2 AND recommender_id=$3`,
		communityID, providerID, recommenderID,
	)
	if err != nil {
		return err
	}

	_, err = tx.Exec(ctx,
		`UPDATE provider_profiles SET recommendation_count = GREATEST(recommendation_count - 1, 0)
		 WHERE user_id=$1 AND community_id=$2`,
		providerID, communityID,
	)
	if err != nil {
		return err
	}

	if err := tx.Commit(ctx); err != nil {
		return err
	}

	return s.providerSvc.RecomputeScore(ctx, providerID)
}

func (s *RecommendationService) ListByProvider(ctx context.Context, communityID, providerID uuid.UUID) ([]Recommender, error) {
	rows, err := s.db.Query(ctx,
		`SELECT u.id, u.full_name, u.avatar_key, rec.created_at
		 FROM recommendations rec JOIN users u ON u.id = rec.recommender_id
		 WHERE rec.community_id=$1 AND rec.provider_id=$2
		 ORDER BY rec.created_at DESC`,
		communityID, providerID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []Recommender
	for rows.Next() {
		var r Recommender
		rows.Scan(&r.UserID, &r.FullName, &r.AvatarKey, &r.CreatedAt)
		result = append(result, r)
	}
	return result, rows.Err()
}
