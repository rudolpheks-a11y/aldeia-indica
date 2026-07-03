package service

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrAlreadyRecommended = errors.New("you have already recommended this provider")

type RecommendationService struct {
	db          *pgxpool.Pool
	providerSvc *ProviderService
}

func NewRecommendationService(db *pgxpool.Pool, providerSvc *ProviderService) *RecommendationService {
	return &RecommendationService{db: db, providerSvc: providerSvc}
}

// RecommendationCount expõe apenas o total — identidade dos indicadores é preservada.
type RecommendationCount struct {
	Count int `json:"count"`
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
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return ErrAlreadyRecommended
		}
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

var ErrRecommendationNotFound = errors.New("you have not recommended this provider")

func (s *RecommendationService) Delete(ctx context.Context, communityID, providerID, recommenderID uuid.UUID) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	tag, err := tx.Exec(ctx,
		`DELETE FROM recommendations WHERE community_id=$1 AND provider_id=$2 AND recommender_id=$3`,
		communityID, providerID, recommenderID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrRecommendationNotFound
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

func (s *RecommendationService) ListByProvider(ctx context.Context, communityID, providerID uuid.UUID) (*RecommendationCount, error) {
	var rc RecommendationCount
	err := s.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM recommendations WHERE community_id=$1 AND provider_id=$2`,
		communityID, providerID,
	).Scan(&rc.Count)
	return &rc, err
}
