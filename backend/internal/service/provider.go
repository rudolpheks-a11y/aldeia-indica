package service

import (
	"context"
	"fmt"
	"time"

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
	DayOfWeek    int // -1 = sem filtro, 0-6 = dia da semana
	Sort         string
	Page         int
	Limit        int
}

type ProviderSummary struct {
	UserID              uuid.UUID `json:"user_id"`
	FullName            string    `json:"full_name"`
	AvatarKey           *string   `json:"avatar_key"`
	City                string    `json:"city"`
	YearsInNeighborhood int       `json:"years_in_neighborhood"`
	ScoreAldeia         float64   `json:"score_aldeia"`
	AvgRating           *float64  `json:"avg_rating"`
	RecommendationCount int       `json:"recommendation_count"`
	Categories          []string  `json:"categories"`
	Seals               []string  `json:"seals"`
}

func (s *ProviderService) Search(ctx context.Context, communityID uuid.UUID, f SearchFilters) ([]ProviderSummary, error) {
	if f.Limit == 0 {
		f.Limit = 20
	}
	offset := f.Page * f.Limit

	sortCol := "pp.score_aldeia DESC"
	switch f.Sort {
	case "rating":
		sortCol = "pp.avg_rating DESC NULLS LAST"
	case "recommendations":
		sortCol = "pp.recommendation_count DESC"
	case "hires":
		sortCol = "pp.total_hires DESC"
	}

	// EXISTS subquery avoids the DISTINCT ON / ORDER BY conflict that would
	// prevent sorting by score or rating when a provider has multiple categories.
	query := fmt.Sprintf(`
		SELECT u.id, u.full_name, u.avatar_key,
		       pp.city, pp.years_in_neighborhood, pp.score_aldeia,
		       pp.avg_rating, pp.recommendation_count
		FROM provider_profiles pp
		JOIN users u ON u.id = pp.user_id
		WHERE pp.community_id = $1
		  AND pp.is_visible = true
		  AND ($2 = '' OR EXISTS (
		        SELECT 1 FROM provider_services ps
		        JOIN service_categories sc ON sc.id = ps.category_id
		        WHERE ps.provider_id = pp.user_id AND sc.slug = $2))
		  AND ($3 = '' OR pp.city ILIKE '%%' || $3 || '%%')
		  AND ($4 = 0 OR pp.avg_rating >= $4)
		  AND ($5 = 0 OR pp.years_in_neighborhood >= $5)
		  AND ($6 = -1 OR EXISTS (
		        SELECT 1 FROM provider_availability pa
		        WHERE pa.provider_id = pp.user_id AND pa.day_of_week = $6))
		ORDER BY %s
		LIMIT $7 OFFSET $8
	`, sortCol)

	rows, err := s.db.Query(ctx, query,
		communityID, f.CategorySlug, f.City, f.MinRating, f.MinTenure, f.DayOfWeek, f.Limit, offset,
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
		p.Seals = s.computeSeals(ctx, p.UserID, p.RecommendationCount, p.AvgRating, s.totalClients(ctx, p.UserID))
		results = append(results, p)
	}
	return results, rows.Err()
}

// Featured retorna até 3 prestadores em destaque para o dia atual.
// Elegível: is_visible=true + pelo menos 1 critério de selo atingido.
// Rotatividade determinística via MD5(user_id || current_date).
func (s *ProviderService) Featured(ctx context.Context, communityID uuid.UUID) ([]ProviderSummary, error) {
	rows, err := s.db.Query(ctx, `
		SELECT u.id, u.full_name, u.avatar_key,
		       pp.city, pp.years_in_neighborhood, pp.score_aldeia,
		       pp.avg_rating, pp.recommendation_count
		FROM provider_profiles pp
		JOIN users u ON u.id = pp.user_id
		WHERE pp.community_id = $1
		  AND pp.is_visible = true
		  AND (
		        (pp.avg_rating >= 4.2 AND pp.total_clients >= 5)
		     OR pp.recommendation_count >= 3
		     OR u.created_at <= now() - interval '12 months'
		     OR (
		          pp.professional_bio IS NOT NULL
		          AND EXISTS (SELECT 1 FROM provider_services WHERE provider_id = pp.user_id)
		          AND EXISTS (SELECT 1 FROM provider_availability WHERE provider_id = pp.user_id)
		          AND EXISTS (SELECT 1 FROM provider_photos WHERE provider_id = pp.user_id)
		        )
		  )
		ORDER BY MD5(pp.user_id::text || current_date::text)
		LIMIT 3
	`, communityID)
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
		p.Seals = s.computeSeals(ctx, p.UserID, p.RecommendationCount, p.AvgRating, s.totalClients(ctx, p.UserID))
		results = append(results, p)
	}
	return results, rows.Err()
}

// computeSeals calcula dinamicamente os selos do prestador.
func (s *ProviderService) computeSeals(ctx context.Context, providerID uuid.UUID, recCount int, avgRating *float64, ratingCount int) []string {
	var seals []string

	if avgRating != nil && *avgRating >= 4.2 && ratingCount >= 5 {
		seals = append(seals, "bem_avaliado")
	}
	if recCount >= 3 {
		seals = append(seals, "muito_indicado")
	}

	var createdAt time.Time
	_ = s.db.QueryRow(ctx, `SELECT created_at FROM users WHERE id=$1`, providerID).Scan(&createdAt)
	if !createdAt.IsZero() && time.Since(createdAt) >= 365*24*time.Hour {
		seals = append(seals, "veterano")
	}

	var hasBio, hasCat, hasAvail, hasPhoto bool
	_ = s.db.QueryRow(ctx,
		`SELECT
		    pp.professional_bio IS NOT NULL,
		    EXISTS (SELECT 1 FROM provider_services WHERE provider_id=$1),
		    EXISTS (SELECT 1 FROM provider_availability WHERE provider_id=$1),
		    EXISTS (SELECT 1 FROM provider_photos WHERE provider_id=$1)
		 FROM provider_profiles pp WHERE pp.user_id=$1`,
		providerID,
	).Scan(&hasBio, &hasCat, &hasAvail, &hasPhoto)
	if hasBio && hasCat && hasAvail && hasPhoto {
		seals = append(seals, "completo")
	}

	return seals
}

func (s *ProviderService) totalClients(ctx context.Context, providerID uuid.UUID) int {
	var n int
	_ = s.db.QueryRow(ctx, `SELECT total_clients FROM provider_profiles WHERE user_id=$1`, providerID).Scan(&n)
	return n
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

func (s *ProviderService) getAvailability(ctx context.Context, providerID uuid.UUID) []AvailabilitySlot {
	rows, _ := s.db.Query(ctx,
		`SELECT day_of_week, start_time, end_time
		 FROM provider_availability WHERE provider_id = $1 ORDER BY day_of_week`,
		providerID,
	)
	defer rows.Close()
	var slots []AvailabilitySlot
	for rows.Next() {
		var sl AvailabilitySlot
		rows.Scan(&sl.DayOfWeek, &sl.StartTime, &sl.EndTime)
		slots = append(slots, sl)
	}
	return slots
}

func (s *ProviderService) UpdateAvailability(ctx context.Context, communityID, userID uuid.UUID, slots []AvailabilitySlot) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `DELETE FROM provider_availability WHERE provider_id=$1`, userID)
	if err != nil {
		return err
	}

	for _, sl := range slots {
		_, err = tx.Exec(ctx,
			`INSERT INTO provider_availability (provider_id, community_id, day_of_week, start_time, end_time)
			 VALUES ($1, $2, $3, $4, $5)`,
			userID, communityID, sl.DayOfWeek, sl.StartTime, sl.EndTime,
		)
		if err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}

func (s *ProviderService) getCategorySlugs(ctx context.Context, providerID uuid.UUID) []string {
	rows, _ := s.db.Query(ctx,
		`SELECT sc.slug FROM provider_services ps
		 JOIN service_categories sc ON sc.id = ps.category_id
		 WHERE ps.provider_id = $1 ORDER BY sc.sort_order`,
		providerID,
	)
	defer rows.Close()
	var slugs []string
	for rows.Next() {
		var s string
		rows.Scan(&s)
		slugs = append(slugs, s)
	}
	return slugs
}

type AvailabilitySlot struct {
	DayOfWeek int    `json:"day_of_week"` // 0=Dom … 6=Sáb
	StartTime string `json:"start_time"`  // "08:00"
	EndTime   string `json:"end_time"`    // "18:00"
}

type ProviderDetail struct {
	ProviderSummary
	ProfessionalBio *string                `json:"professional_bio"`
	TotalClients    int                    `json:"total_clients"`
	TotalHires      int                    `json:"total_hires"`
	NeedsTransport  bool                   `json:"needs_transport"`
	TransportType   *string                `json:"transport_type"`
	CategorySlugs   []string               `json:"category_slugs"`
	Availability    []AvailabilitySlot     `json:"availability"`
	Photos          []domain.ProviderPhoto `json:"photos"`
}

func (s *ProviderService) Get(ctx context.Context, communityID, providerID uuid.UUID) (*ProviderDetail, error) {
	var d ProviderDetail
	err := s.db.QueryRow(ctx,
		`SELECT u.id, u.full_name, u.avatar_key,
		        pp.city, pp.years_in_neighborhood, pp.score_aldeia,
		        pp.avg_rating, pp.recommendation_count,
		        pp.professional_bio, pp.total_clients, pp.total_hires,
		        pp.needs_transport, pp.transport_type
		 FROM provider_profiles pp
		 JOIN users u ON u.id = pp.user_id
		 WHERE pp.community_id = $1 AND pp.user_id = $2`,
		communityID, providerID,
	).Scan(
		&d.UserID, &d.FullName, &d.AvatarKey,
		&d.City, &d.YearsInNeighborhood, &d.ScoreAldeia,
		&d.AvgRating, &d.RecommendationCount,
		&d.ProfessionalBio, &d.TotalClients, &d.TotalHires,
		&d.NeedsTransport, &d.TransportType,
	)
	if err != nil {
		return nil, err
	}
	d.Categories = s.getCategories(ctx, providerID)
	d.CategorySlugs = s.getCategorySlugs(ctx, providerID)
	d.Availability = s.getAvailability(ctx, providerID)
	d.Photos = s.getPhotos(ctx, providerID)
	d.Seals = s.computeSeals(ctx, providerID, d.RecommendationCount, d.AvgRating, d.TotalClients)
	return &d, nil
}

func (s *ProviderService) GetMe(ctx context.Context, communityID, userID uuid.UUID) (*ProviderDetail, error) {
	return s.Get(ctx, communityID, userID)
}

// RatingSummary é o que o prestador pode ver sobre suas próprias avaliações.
type RatingSummary struct {
	AvgRating *float64 `json:"avg_rating"`
	Count     int      `json:"count"`
}

func (s *ProviderService) MyRatingSummary(ctx context.Context, communityID, providerID uuid.UUID) (*RatingSummary, error) {
	var rs RatingSummary
	err := s.db.QueryRow(ctx,
		`SELECT pp.avg_rating, pp.total_clients
		 FROM provider_profiles pp
		 WHERE pp.community_id=$1 AND pp.user_id=$2`,
		communityID, providerID,
	).Scan(&rs.AvgRating, &rs.Count)
	if err != nil {
		return nil, err
	}
	return &rs, nil
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
	City                *string
	YearsInNeighborhood *int
	ProfessionalBio     *string
	CategorySlugs       *[]string
	NeedsTransport      *bool
	TransportType       *string
}

func (s *ProviderService) UpdateMe(ctx context.Context, communityID, userID uuid.UUID, in UpdateProviderInput) error {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Patch-style: COALESCE keeps existing value when field is nil.
	// transport_type is updated only when needs_transport is explicitly set.
	_, err = tx.Exec(ctx,
		`UPDATE provider_profiles SET
		    city                 = COALESCE($1, city),
		    years_in_neighborhood = COALESCE($2, years_in_neighborhood),
		    professional_bio     = COALESCE($3, professional_bio),
		    needs_transport      = COALESCE($4, needs_transport),
		    transport_type       = CASE WHEN $4 IS NOT NULL THEN $5 ELSE transport_type END,
		    updated_at           = now()
		 WHERE user_id=$6 AND community_id=$7`,
		in.City, in.YearsInNeighborhood, in.ProfessionalBio,
		in.NeedsTransport, in.TransportType, userID, communityID,
	)
	if err != nil {
		return err
	}

	if in.CategorySlugs != nil {
		_, err = tx.Exec(ctx, `DELETE FROM provider_services WHERE provider_id=$1`, userID)
		if err != nil {
			return err
		}
		for _, slug := range *in.CategorySlugs {
			_, err = tx.Exec(ctx,
				`INSERT INTO provider_services (provider_id, category_id, community_id)
				 SELECT $1, id, $2 FROM service_categories WHERE slug=$3`,
				userID, communityID, slug,
			)
			if err != nil {
				return fmt.Errorf("insert category %s: %w", slug, err)
			}
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
