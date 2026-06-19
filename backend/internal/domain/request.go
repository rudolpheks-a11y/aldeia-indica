package domain

import (
	"time"

	"github.com/google/uuid"
)

type RequestStatus string

const (
	RequestOpen       RequestStatus = "open"
	RequestInProgress RequestStatus = "in_progress"
	RequestClosed     RequestStatus = "closed"
)

type ServiceRequest struct {
	ID          uuid.UUID
	CommunityID uuid.UUID
	RequesterID uuid.UUID
	CategoryID  *int
	Title       string
	Description *string
	DesiredDate *time.Time
	Status      RequestStatus
	CreatedAt   time.Time
}

type ServiceResponse struct {
	ID         uuid.UUID
	RequestID  uuid.UUID
	ProviderID uuid.UUID
	Message    string
	CreatedAt  time.Time
}
