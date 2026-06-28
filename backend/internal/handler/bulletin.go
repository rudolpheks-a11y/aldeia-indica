package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
)

type BulletinHandler struct {
	svc *service.BulletinService
}

func NewBulletinHandler(svc *service.BulletinService) *BulletinHandler {
	return &BulletinHandler{svc: svc}
}

func (h *BulletinHandler) Create(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	var in struct {
		Content string `json:"content"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil || in.Content == "" {
		jsonError(w, "content is required", http.StatusBadRequest)
		return
	}

	if err := h.svc.Create(r.Context(), claims.CommunityID, claims.UserID, in.Content); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

func (h *BulletinHandler) ListApproved(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	posts, err := h.svc.ListApproved(r.Context(), claims.CommunityID)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonOK(w, posts)
}

func (h *BulletinHandler) ListPending(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	posts, err := h.svc.ListPending(r.Context(), claims.CommunityID)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonOK(w, posts)
}

func (h *BulletinHandler) Review(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	postID, err := uuid.Parse(chi.URLParam(r, "id"))
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

	if err := h.svc.Review(r.Context(), claims.CommunityID, postID, claims.UserID, in.Approve); err != nil {
		jsonError(w, "not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
