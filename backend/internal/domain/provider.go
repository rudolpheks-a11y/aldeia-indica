package domain

import (
	"time"

	"github.com/google/uuid"
)

type DocStatus string

const (
	DocPending     DocStatus = "pending"
	DocUnderReview DocStatus = "under_review"
	DocApproved    DocStatus = "approved"
	DocRejected    DocStatus = "rejected"
)

type ProviderProfile struct {
	UserID               uuid.UUID
	CommunityID          uuid.UUID
	City                 string
	YearsInNeighborhood  int
	ProfessionalBio      *string
	ScoreAldeia          float64
	TotalClients         int
	TotalHires           int
	RecommendationCount  int
	AvgRating            *float64
	DocStatus            DocStatus
	IsVisible            bool
	UpdatedAt            time.Time
}

type ProviderPhoto struct {
	ID         uuid.UUID
	ProviderID uuid.UUID
	S3Key      string
	Caption    *string
	SortOrder  int
	UploadedAt time.Time
}
