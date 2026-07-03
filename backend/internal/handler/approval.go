package handler

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
)

type ApprovalHandler struct {
	userSvc *service.UserService
}

func NewApprovalHandler(userSvc *service.UserService) *ApprovalHandler {
	return &ApprovalHandler{userSvc: userSvc}
}

func (h *ApprovalHandler) ListPending(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	pending, err := h.userSvc.ListPending(r.Context(), claims.CommunityID)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonOK(w, pending)
}

func (h *ApprovalHandler) Vote(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	approvalID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	if err := h.userSvc.Vote(r.Context(), claims.UserID, claims.CommunityID, approvalID); err != nil {
		if errors.Is(err, service.ErrAlreadyVoted) {
			jsonError(w, err.Error(), http.StatusConflict)
			return
		}
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ApprovalHandler) AdminResolve(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	approvalID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	var in struct {
		Approve bool `json:"approve"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	if err := h.userSvc.AdminResolve(r.Context(), claims.UserID, claims.CommunityID, approvalID, in.Approve); err != nil {
		jsonError(w, "approval not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ApprovalHandler) CreateInvite(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	var in struct {
		IntendedEmail string `json:"intended_email"`
	}
	json.NewDecoder(r.Body).Decode(&in)

	token, err := h.userSvc.CreateInvite(r.Context(), claims.UserID, claims.CommunityID, in.IntendedEmail)
	if err != nil {
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

func (h *ApprovalHandler) UseInvite(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	token := chi.URLParam(r, "token")

	if err := h.userSvc.UseInvite(r.Context(), token, claims.UserID); err != nil {
		jsonError(w, "invalid invite", http.StatusBadRequest)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
