package auth

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/domain"
)

type jwtClaims struct {
	UserID      string `json:"uid"`
	CommunityID string `json:"cid"`
	Role        string `json:"role"`
	jwt.RegisteredClaims
}

type JWT struct {
	secret        []byte
	accessExpiry  time.Duration
	refreshExpiry time.Duration
}

func NewJWT(secret string, accessExpiry, refreshExpiry time.Duration) *JWT {
	return &JWT{
		secret:        []byte(secret),
		accessExpiry:  accessExpiry,
		refreshExpiry: refreshExpiry,
	}
}

func (j *JWT) IssueAccess(claims domain.Claims) (string, error) {
	c := jwtClaims{
		UserID:      claims.UserID.String(),
		CommunityID: claims.CommunityID.String(),
		Role:        string(claims.Role),
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(j.accessExpiry)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, c).SignedString(j.secret)
}

func (j *JWT) Parse(tokenStr string) (*domain.Claims, error) {
	t, err := jwt.ParseWithClaims(tokenStr, &jwtClaims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return j.secret, nil
	})
	if err != nil {
		return nil, err
	}

	c, ok := t.Claims.(*jwtClaims)
	if !ok || !t.Valid {
		return nil, errors.New("invalid token")
	}

	userID, err := uuid.Parse(c.UserID)
	if err != nil {
		return nil, err
	}
	communityID, err := uuid.Parse(c.CommunityID)
	if err != nil {
		return nil, err
	}

	return &domain.Claims{
		UserID:      userID,
		CommunityID: communityID,
		Role:        domain.UserRole(c.Role),
	}, nil
}
