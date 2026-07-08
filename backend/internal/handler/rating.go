package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
)

type RatingHandler struct {
	svc *service.RatingService
}

func NewRatingHandler(svc *service.RatingService) *RatingHandler {
	return &RatingHandler{svc: svc}
}

func (h *RatingHandler) Create(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	var in struct {
		ProviderID  string `json:"provider_id"`
		Quality     int    `json:"quality"`
		Punctuality int    `json:"punctuality"`
		Politeness  int    `json:"politeness"`
		Reliability int    `json:"reliability"`
		Comment     string `json:"comment"`
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

	err = h.svc.Create(r.Context(), service.CreateRatingInput{
		CommunityID: claims.CommunityID,
		ProviderID:  providerID,
		RaterID:     claims.UserID,
		Quality:     in.Quality,
		Punctuality: in.Punctuality,
		Politeness:  in.Politeness,
		Reliability: in.Reliability,
		Comment:     in.Comment,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrAlreadyRated):
			jsonError(w, err.Error(), http.StatusConflict)
		case errors.Is(err, service.ErrInvalidRatingValue):
			jsonError(w, err.Error(), http.StatusBadRequest)
		case errors.Is(err, service.ErrCannotRateSelf):
			jsonError(w, err.Error(), http.StatusForbidden)
		default:
			jsonError(w, "internal error", http.StatusInternalServerError)
		}
		return
	}
	w.WriteHeader(http.StatusCreated)
}

func (h *RatingHandler) ListByProvider(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	providerID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	// Prestador não pode ver suas próprias avaliações individuais (preserva anonimato dos avaliadores)
	if claims.UserID == providerID {
		jsonError(w, "providers cannot view their own individual ratings", http.StatusForbidden)
		return
	}

	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	ratings, err := h.svc.ListByProvider(r.Context(), claims.CommunityID, providerID, page, 20)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonOK(w, ratings)
}
