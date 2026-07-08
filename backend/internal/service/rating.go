package service

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type RatingService struct {
	db          *pgxpool.Pool
	providerSvc *ProviderService
	notifSvc    *NotificationService
}

func NewRatingService(db *pgxpool.Pool, providerSvc *ProviderService, notifSvc *NotificationService) *RatingService {
	return &RatingService{db: db, providerSvc: providerSvc, notifSvc: notifSvc}
}

type CreateRatingInput struct {
	CommunityID uuid.UUID
	ProviderID  uuid.UUID
	RaterID     uuid.UUID
	Quality     int
	Punctuality int
	Politeness  int
	Reliability int
	Comment     string
}

var (
	ErrAlreadyRated       = errors.New("you have already rated this provider")
	ErrInvalidRatingValue = errors.New("rating values must be between 1 and 5")
	ErrCannotRateSelf     = errors.New("cannot rate yourself")
)

func (s *RatingService) Create(ctx context.Context, in CreateRatingInput) error {
	if in.RaterID == in.ProviderID {
		return ErrCannotRateSelf
	}
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx,
		`INSERT INTO ratings (community_id, provider_id, rater_id, quality, punctuality, politeness, reliability, comment)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
		in.CommunityID, in.ProviderID, in.RaterID,
		in.Quality, in.Punctuality, in.Politeness, in.Reliability, in.Comment,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23514" {
			return ErrInvalidRatingValue
		}
		return ErrAlreadyRated
	}

	_, err = tx.Exec(ctx,
		`UPDATE provider_profiles SET
		    avg_rating = (
		        SELECT AVG((quality+punctuality+politeness+reliability)::float/4)
		        FROM ratings WHERE community_id=$1 AND provider_id=$2
		    ),
		    total_clients = (
		        SELECT COUNT(DISTINCT rater_id) FROM ratings WHERE community_id=$1 AND provider_id=$2
		    ),
		    updated_at = now()
		 WHERE user_id=$2 AND community_id=$1`,
		in.CommunityID, in.ProviderID,
	)
	if err != nil {
		return err
	}

	if err := tx.Commit(ctx); err != nil {
		return err
	}

	// Best-effort: a avaliação já foi salva, não deixamos uma falha aqui
	// derrubar a resposta de sucesso pro morador.
	_ = s.notifSvc.Create(ctx, in.CommunityID, in.ProviderID,
		"rating_received", "Nova avaliação recebida",
		"Você recebeu uma nova avaliação de um morador.", nil)

	return s.providerSvc.RecomputeScore(ctx, in.ProviderID)
}

type RatingRow struct {
	ID          uuid.UUID `json:"id"`
	RaterName   string    `json:"rater_name"`
	Quality     int       `json:"quality"`
	Punctuality int       `json:"punctuality"`
	Politeness  int       `json:"politeness"`
	Reliability int       `json:"reliability"`
	Overall     float64   `json:"overall"`
	Comment     *string   `json:"comment"`
	CreatedAt   time.Time `json:"created_at"`
}

func (s *RatingService) ListByProvider(ctx context.Context, communityID, providerID uuid.UUID, page, limit int) ([]RatingRow, error) {
	if limit == 0 {
		limit = 20
	}
	offset := page * limit

	rows, err := s.db.Query(ctx,
		`SELECT r.id, u.full_name, r.quality, r.punctuality, r.politeness, r.reliability,
		        (r.quality+r.punctuality+r.politeness+r.reliability)::float/4 AS overall,
		        r.comment, r.created_at
		 FROM ratings r JOIN users u ON u.id = r.rater_id
		 WHERE r.community_id=$1 AND r.provider_id=$2
		 ORDER BY r.created_at DESC
		 LIMIT $3 OFFSET $4`,
		communityID, providerID, limit, offset,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []RatingRow
	for rows.Next() {
		var row RatingRow
		if err := rows.Scan(&row.ID, &row.RaterName, &row.Quality, &row.Punctuality,
			&row.Politeness, &row.Reliability, &row.Overall, &row.Comment, &row.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, row)
	}
	return result, rows.Err()
}
