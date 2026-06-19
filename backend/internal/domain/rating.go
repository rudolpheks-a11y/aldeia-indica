package domain

import (
	"time"

	"github.com/google/uuid"
)

type Rating struct {
	ID          uuid.UUID
	CommunityID uuid.UUID
	ProviderID  uuid.UUID
	RaterID     uuid.UUID
	Quality     int
	Punctuality int
	Politeness  int
	Reliability int
	Comment     *string
	CreatedAt   time.Time
}

func (r Rating) OverallStars() float64 {
	return float64(r.Quality+r.Punctuality+r.Politeness+r.Reliability) / 4.0
}
