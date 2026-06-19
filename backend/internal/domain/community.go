package domain

import (
	"time"

	"github.com/google/uuid"
)

type Community struct {
	ID        uuid.UUID
	Name      string
	Slug      string
	City      string
	State     string
	IsActive  bool
	CreatedAt time.Time
}
