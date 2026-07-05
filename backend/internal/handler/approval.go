package handler

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
)

type ApprovalHandler struct {
	userSvc *service.UserService
}

func NewApprovalHandler(userSvc *service.UserService) *ApprovalHandler {
	return &ApprovalHandler{userSvc: userSvc}
}

// CreateInvite gera um código de convite — usado por um morador ativo pra
// convidar outro. O candidato precisa de 2 códigos de moradores diferentes
// pra se cadastrar (ver AuthHandler.RegisterMorador).
func (h *ApprovalHandler) CreateInvite(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	var in struct {
		IntendedEmail string `json:"intended_email"`
	}
	json.NewDecoder(r.Body).Decode(&in)

	token, err := h.userSvc.CreateInvite(r.Context(), claims.UserID, claims.CommunityID, claims.Role, in.IntendedEmail)
	if err != nil {
		if errors.Is(err, service.ErrOnlyResidents) {
			jsonError(w, err.Error(), http.StatusForbidden)
			return
		}
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonOK(w, map[string]string{"token": token})
}

func (h *ApprovalHandler) ValidateInvite(w http.ResponseWriter, r *http.Request) {
	token := chi.URLParam(r, "token")
	communityID, err := h.userSvc.ValidateInvite(r.Context(), token)
	if err != nil {
		jsonError(w, "invalid invite", http.StatusNotFound)
		return
	}
	jsonOK(w, map[string]string{"community_id": communityID.String()})
}
