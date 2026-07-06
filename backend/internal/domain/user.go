package domain

import (
	"time"

	"github.com/google/uuid"
)

type UserRole string
type UserStatus string

const (
	RoleMorador   UserRole = "morador"
	RolePrestador UserRole = "prestador"
	RoleAdmin     UserRole = "admin"

	StatusPending   UserStatus = "pending"
	StatusActive    UserStatus = "active"
	StatusSuspended UserStatus = "suspended"
)

type User struct {
	ID          uuid.UUID
	CommunityID uuid.UUID
	Email       string
	Role        UserRole
	Status      UserStatus
	FullName    string
	AvatarKey   *string
	Phone       *string
	CreatedAt   time.Time
}

type Claims struct {
	UserID      uuid.UUID
	CommunityID uuid.UUID
	Role        UserRole
}
