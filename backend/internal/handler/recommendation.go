package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
)

type RecommendationHandler struct {
	svc *service.RecommendationService
}

func NewRecommendationHandler(svc *service.RecommendationService) *RecommendationHandler {
	return &RecommendationHandler{svc: svc}
}

func (h *RecommendationHandler) Create(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	var in struct {
		ProviderID string `json:"provider_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	providerID, err := uuid.Parse(in.ProviderID)
	if err != nil {
		jsonError(w, "invalid provider_id", http.StatusBadRequest)
		return
	}

	if err := h.svc.Create(r.Context(), claims.CommunityID, providerID, claims.UserID); err != nil {
		jsonError(w, err.Error(), http.StatusBadRequest)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

func (h *RecommendationHandler) Delete(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	var in struct {
		ProviderID string `json:"provider_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	providerID, err := uuid.Parse(in.ProviderID)
	if err != nil {
		jsonError(w, "invalid provider_id", http.StatusBadRequest)
		return
	}

	if err := h.svc.Delete(r.Context(), claims.CommunityID, providerID, claims.UserID); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *RecommendationHandler) ListByProvider(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	providerID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	list, err := h.svc.ListByProvider(r.Context(), claims.CommunityID, providerID)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonOK(w, list)
}
