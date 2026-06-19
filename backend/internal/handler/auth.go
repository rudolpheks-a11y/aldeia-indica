package handler

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/google/uuid"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
)

type AuthHandler struct {
	svc *service.AuthService
}

func NewAuthHandler(svc *service.AuthService) *AuthHandler {
	return &AuthHandler{svc: svc}
}

func (h *AuthHandler) RegisterMorador(w http.ResponseWriter, r *http.Request) {
	var in struct {
		CommunityID       string `json:"community_id"`
		Email             string `json:"email"`
		Password          string `json:"password"`
		FullName          string `json:"full_name"`
		StreetAddress     string `json:"street_address"`
		HouseNumber       string `json:"house_number"`
		NeighborhoodBlock string `json:"neighborhood_block"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	communityID, err := uuid.Parse(in.CommunityID)
	if err != nil {
		jsonError(w, "invalid community_id", http.StatusBadRequest)
		return
	}

	userID, err := h.svc.RegisterMorador(r.Context(), service.RegisterMoradorInput{
		CommunityID:       communityID,
		Email:             in.Email,
		Password:          in.Password,
		FullName:          in.FullName,
		StreetAddress:     in.StreetAddress,
		HouseNumber:       in.HouseNumber,
		NeighborhoodBlock: in.NeighborhoodBlock,
	})
	if err != nil {
		jsonError(w, err.Error(), http.StatusBadRequest)
		return
	}

	jsonOK(w, map[string]string{"user_id": userID.String(), "status": "pending"})
}

func (h *AuthHandler) RegisterPrestador(w http.ResponseWriter, r *http.Request) {
	var in struct {
		CommunityID         string `json:"community_id"`
		Email               string `json:"email"`
		Password            string `json:"password"`
		FullName            string `json:"full_name"`
		City                string `json:"city"`
		YearsInNeighborhood int    `json:"years_in_neighborhood"`
		ProfessionalBio     string `json:"professional_bio"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	communityID, err := uuid.Parse(in.CommunityID)
	if err != nil {
		jsonError(w, "invalid community_id", http.StatusBadRequest)
		return
	}

	userID, err := h.svc.RegisterPrestador(r.Context(), service.RegisterPrestadorInput{
		CommunityID:         communityID,
		Email:               in.Email,
		Password:            in.Password,
		FullName:            in.FullName,
		City:                in.City,
		YearsInNeighborhood: in.YearsInNeighborhood,
		ProfessionalBio:     in.ProfessionalBio,
	})
	if err != nil {
		jsonError(w, err.Error(), http.StatusBadRequest)
		return
	}

	jsonOK(w, map[string]string{"user_id": userID.String(), "status": "pending"})
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var in struct {
		CommunityID string `json:"community_id"`
		Email       string `json:"email"`
		Password    string `json:"password"`
		DeviceInfo  string `json:"device_info"`
		Platform    string `json:"platform"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	communityID, err := uuid.Parse(in.CommunityID)
	if err != nil {
		jsonError(w, "invalid community_id", http.StatusBadRequest)
		return
	}

	pair, err := h.svc.Login(r.Context(), service.LoginInput{
		CommunityID: communityID,
		Email:       in.Email,
		Password:    in.Password,
		DeviceInfo:  in.DeviceInfo,
		Platform:    in.Platform,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidCredentials):
			jsonError(w, "invalid credentials", http.StatusUnauthorized)
		case errors.Is(err, service.ErrUserPending):
			jsonError(w, "account pending approval", http.StatusForbidden)
		case errors.Is(err, service.ErrUserSuspended):
			jsonError(w, "account suspended", http.StatusForbidden)
		default:
			jsonError(w, "internal error", http.StatusInternalServerError)
		}
		return
	}

	jsonOK(w, pair)
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var in struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	pair, err := h.svc.Refresh(r.Context(), in.RefreshToken)
	if err != nil {
		jsonError(w, "invalid refresh token", http.StatusUnauthorized)
		return
	}

	jsonOK(w, pair)
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	var in struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	_ = h.svc.Logout(r.Context(), in.RefreshToken)
	w.WriteHeader(http.StatusNoContent)
}

func jsonOK(w http.ResponseWriter, data any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

func jsonError(w http.ResponseWriter, msg string, code int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}
