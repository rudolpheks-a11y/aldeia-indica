package domain

import (
	"time"

	"github.com/google/uuid"
)

type ProviderProfile struct {
	UserID              uuid.UUID
	CommunityID         uuid.UUID
	City                string
	YearsInNeighborhood int
	ProfessionalBio     *string
	ScoreAldeia         float64
	TotalClients        int
	RecommendationCount int
	AvgRating           *float64
	IsVisible           bool
	UpdatedAt           time.Time
}

type ProviderPhoto struct {
	ID         uuid.UUID
	ProviderID uuid.UUID
	S3Key      string
	Caption    *string
	SortOrder  int
	UploadedAt time.Time
}
