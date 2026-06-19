package service

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/domain"
)

type ProviderService struct {
	db *pgxpool.Pool
}

func NewProviderService(db *pgxpool.Pool) *ProviderService {
	return &ProviderService{db: db}
}

type SearchFilters struct {
	CategorySlug string
	City         string
	MinRating    float64
	MinTenure    int
	Sort         string
	Page         int
	Limit        int
}

type ProviderSummary struct {
	UserID              uuid.UUID  `json:"user_id"`
	FullName            string     `json:"full_name"`
	AvatarKey           *string    `json:"avatar_key"`
	City                string     `json:"city"`
	YearsInNeighborhood int        `json:"years_in_neighborhood"`
	ScoreAldeia         float64    `json:"score_aldeia"`
	AvgRating           *float64   `json:"avg_rating"`
	RecommendationCount int        `json:"recommendation_count"`
	Categories          []string   `json:"categories"`
}

func (s *ProviderService) Search(ctx context.Context, communityID uuid.UUID, f SearchFilters) ([]ProviderSummary, error) {
	if f.Limit == 0 {
		f.Limit = 20
	}
	offset := (f.Page) * f.Limit

	sortCol := "pp.score_aldeia DESC"
	switch f.Sort {
	case "rating":
		sortCol = "pp.avg_rating DESC NULLS LAST"
	case "recommendations":
		sortCol = "pp.recommendation_count DESC"
	case "hires":
		sortCol = "pp.total_hires DESC"
	}

	query := fmt.Sprintf(`
		SELECT DISTINCT ON (u.id)
		       u.id, u.full_name, u.avatar_key,
		       pp.city, pp.years_in_neighborhood, pp.score_aldeia,
		       pp.avg_rating, pp.recommendation_count
		FROM provider_profiles pp
		JOIN users u ON u.id = pp.user_id
		LEFT JOIN provider_services ps ON ps.provider_id = pp.user_id
		LEFT JOIN service_categories sc ON sc.id = ps.category_id
		WHERE pp.community_id = $1
		  AND pp.is_visible = true
		  AND ($2 = '' OR sc.slug = $2)
		  AND ($3 = '' OR pp.city ILIKE '%%' || $3 || '%%')
		  AND ($4 = 0 OR pp.avg_rating >= $4)
		  AND ($5 = 0 OR pp.years_in_neighborhood >= $5)
		ORDER BY u.id, %s
		LIMIT $6 OFFSET $7
	`, sortCol)

	rows, err := s.db.Query(ctx, query,
		communityID, f.CategorySlug, f.City, f.MinRating, f.MinTenure, f.Limit, offset,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []ProviderSummary
	for rows.Next() {
		var p ProviderSummary
		if err := rows.Scan(
			&p.UserID, &p.FullName, &p.AvatarKey,
			&p.City, &p.YearsInNeighborhood, &p.ScoreAldeia,
			&p.AvgRating, &p.RecommendationCount,
		); err != nil {
			return nil, err
		}
		p.Categories = s.getCategories(ctx, p.UserID)
		results = append(results, p)
	}
	return results, rows.Err()
}

func (s *ProviderService) getCategories(ctx context.Context, providerID uuid.UUID) []string {
	rows, _ := s.db.Query(ctx,
		`SELECT sc.name_pt FROM provider_services ps
		 JOIN service_categories sc ON sc.id = ps.category_id
		 WHERE ps.provider_id = $1 ORDER BY sc.sort_order`,
		providerID,
	)
	defer rows.Close()
	var cats []string
	for rows.Next() {
		var c string
		rows.Scan(&c)
		cats = append(cats, c)
	}
	return cats
}

type ProviderDetail struct {
	ProviderSummary
	ProfessionalBio *string           `json:"professional_bio"`
	TotalClients    int               `json:"total_clients"`
	TotalHires      int               `json:"total_hires"`
	Photos          []domain.ProviderPhoto `json:"photos"`
}

func (s *ProviderService) Get(ctx context.Context, communityID, providerID uuid.UUID) (*ProviderDetail, error) {
	var d ProviderDetail
	err := s.db.QueryRow(ctx,
		`SELECT u.id, u.full_name, u.avatar_key,
		        pp.city, pp.years_in_neighborhood, pp.score_aldeia,
		        pp.avg_rating, pp.recommendation_count,
		        pp.professional_bio, pp.total_clients, pp.total_hires
		 FROM provider_profiles pp
		 JOIN users u ON u.id = pp.user_id
		 WHERE pp.community_id = $1 AND pp.user_id = $2`,
		communityID, providerID,
	).Scan(
		&d.UserID, &d.FullName, &d.AvatarKey,
		&d.City, &d.YearsInNeighborhood, &d.ScoreAldeia,
		&d.AvgRating, &d.RecommendationCount,
		&d.ProfessionalBio, &d.TotalClients, &d.TotalHires,
	)
	if err != nil {
		return nil, err
	}
	d.Categories = s.getCategories(ctx, providerID)
	d.Photos = s.getPhotos(ctx, providerID)
	return &d, nil
}

func (s *ProviderService) getPhotos(ctx context.Context, providerID uuid.UUID) []domain.ProviderPhoto {
	rows, _ := s.db.Query(ctx,
		`SELECT id, provider_id, s3_key, caption, sort_order, uploaded_at
		 FROM provider_photos WHERE provider_id = $1 ORDER BY sort_order, uploaded_at`,
		providerID,
	)
	defer rows.Close()
	var photos []domain.ProviderPhoto
	for rows.Next() {
		var p domain.ProviderPhoto
		rows.Scan(&p.ID, &p.ProviderID, &p.S3Key, &p.Caption, &p.SortOrder, &p.UploadedAt)
		photos = append(photos, p)
	}
	return photos
}

type UpdateProviderInput struct {
	City                string
	YearsInNeighborhood int
	ProfessionalBio     string
	CategorySlugs       []string
}

func (s *ProviderService) UpdateMe(ctx context.Context, communityID, userID uuid.UUID, in UpdateProviderInput) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx,
		`UPDATE provider_profiles SET city=$1, years_in_neighborhood=$2, professional_bio=$3, updated_at=now()
		 WHERE user_id=$4 AND community_id=$5`,
		in.City, in.YearsInNeighborhood, in.ProfessionalBio, userID, communityID,
	)
	if err != nil {
		return err
	}

	_, err = tx.Exec(ctx, `DELETE FROM provider_services WHERE provider_id=$1`, userID)
	if err != nil {
		return err
	}

	for _, slug := range in.CategorySlugs {
		_, err = tx.Exec(ctx,
			`INSERT INTO provider_services (provider_id, category_id, community_id)
			 SELECT $1, id, $2 FROM service_categories WHERE slug=$3`,
			userID, communityID, slug,
		)
		if err != nil {
			return fmt.Errorf("insert category %s: %w", slug, err)
		}
	}

	return tx.Commit(ctx)
}

func (s *ProviderService) AddPhoto(ctx context.Context, communityID, providerID uuid.UUID, s3Key, caption string) error {
	_, err := s.db.Exec(ctx,
		`INSERT INTO provider_photos (provider_id, community_id, s3_key, caption) VALUES ($1,$2,$3,$4)`,
		providerID, communityID, s3Key, caption,
	)
	return err
}

func (s *ProviderService) DeletePhoto(ctx context.Context, providerID, photoID uuid.UUID) error {
	_, err := s.db.Exec(ctx,
		`DELETE FROM provider_photos WHERE id=$1 AND provider_id=$2`,
		photoID, providerID,
	)
	return err
}

func (s *ProviderService) RecomputeScore(ctx context.Context, providerID uuid.UUID) error {
	var stats domain.ProviderStats
	err := s.db.QueryRow(ctx,
		`SELECT COALESCE(avg_rating, 0), years_in_neighborhood, total_clients, total_hires, recommendation_count
		 FROM provider_profiles WHERE user_id=$1`,
		providerID,
	).Scan(&stats.AvgRating, &stats.YearsInNeighborhood, &stats.TotalClients, &stats.TotalHires, &stats.RecommendationCount)
	if err != nil {
		return err
	}

	score := domain.CalculateScore(stats)
	_, err = s.db.Exec(ctx,
		`UPDATE provider_profiles SET score_aldeia=$1, updated_at=now() WHERE user_id=$2`,
		score, providerID,
	)
	return err
}
