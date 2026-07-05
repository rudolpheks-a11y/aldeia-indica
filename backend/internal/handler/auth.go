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
		InviteCode1       string `json:"invite_code_1"`
		InviteCode2       string `json:"invite_code_2"`
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
	if len(in.Password) < 6 {
		jsonError(w, "password must be at least 6 characters", http.StatusBadRequest)
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
		InviteCode1:       in.InviteCode1,
		InviteCode2:       in.InviteCode2,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrEmailTaken):
			jsonError(w, err.Error(), http.StatusConflict)
		case errors.Is(err, service.ErrInvalidInviteCode),
			errors.Is(err, service.ErrSameInviteSponsor),
			errors.Is(err, service.ErrIncompleteInviteCodes):
			jsonError(w, err.Error(), http.StatusBadRequest)
		default:
			jsonError(w, "registration failed", http.StatusBadRequest)
		}
		return
	}

	status := "pending"
	if in.InviteCode1 != "" && in.InviteCode2 != "" {
		status = "active"
	}
	jsonOK(w, map[string]string{"user_id": userID.String(), "status": status})
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
	if len(in.Password) < 6 {
		jsonError(w, "password must be at least 6 characters", http.StatusBadRequest)
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
		if errors.Is(err, service.ErrEmailTaken) {
			jsonError(w, err.Error(), http.StatusConflict)
			return
		}
		jsonError(w, "registration failed", http.StatusBadRequest)
		return
	}

	jsonOK(w, map[string]string{"user_id": userID.String(), "status": "active"})
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

func (h *AuthHandler) ForgotPassword(w http.ResponseWriter, r *http.Request) {
	var in struct {
		CommunityID string `json:"community_id"`
		Email       string `json:"email"`
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

	_ = h.svc.RequestPasswordReset(r.Context(), communityID, in.Email)
	// Always respond with 200 to avoid email enumeration
	jsonOK(w, map[string]string{"message": "if the email exists, a code was sent"})
}

func (h *AuthHandler) ResetPassword(w http.ResponseWriter, r *http.Request) {
	var in struct {
		CommunityID string `json:"community_id"`
		Email       string `json:"email"`
		Code        string `json:"code"`
		NewPassword string `json:"new_password"`
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

	if len(in.NewPassword) < 6 {
		jsonError(w, "password must be at least 6 characters", http.StatusBadRequest)
		return
	}

	if err := h.svc.ResetPassword(r.Context(), communityID, in.Email, in.Code, in.NewPassword); err != nil {
		jsonError(w, "invalid or expired code", http.StatusBadRequest)
		return
	}

	jsonOK(w, map[string]string{"message": "password updated"})
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
