package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
)

type ProviderHandler struct {
	svc      *service.ProviderService
	analytics *service.AnalyticsService
}

func NewProviderHandler(svc *service.ProviderService, analytics *service.AnalyticsService) *ProviderHandler {
	return &ProviderHandler{svc: svc, analytics: analytics}
}

func (h *ProviderHandler) Search(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	q := r.URL.Query()

	minRating, _ := strconv.ParseFloat(q.Get("min_rating"), 64)
	minTenure, _ := strconv.Atoi(q.Get("min_tenure"))
	page, _ := strconv.Atoi(q.Get("page"))

	limit := 20
	if l, err := strconv.Atoi(q.Get("limit")); err == nil && l > 0 && l <= 200 {
		limit = l
	}

	results, err := h.svc.Search(r.Context(), claims.CommunityID, service.SearchFilters{
		CategorySlug: q.Get("category"),
		City:         q.Get("city"),
		MinRating:    minRating,
		MinTenure:    minTenure,
		Sort:         q.Get("sort"),
		Page:         page,
		Limit:        limit,
	})
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonOK(w, results)
}

func (h *ProviderHandler) Get(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	providerID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	detail, err := h.svc.Get(r.Context(), claims.CommunityID, providerID)
	if err != nil {
		jsonError(w, "not found", http.StatusNotFound)
		return
	}

	// Record profile view fire-and-forget
	actorID := claims.UserID
	go h.analytics.RecordEvent(r.Context(), claims.CommunityID, providerID, &actorID, service.EventProfileView)

	jsonOK(w, detail)
}

func (h *ProviderHandler) GetMe(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	detail, err := h.svc.GetMe(r.Context(), claims.CommunityID, claims.UserID)
	if err != nil {
		jsonError(w, "not found", http.StatusNotFound)
		return
	}
	jsonOK(w, detail)
}

func (h *ProviderHandler) UpdateMe(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	var in struct {
		City                *string   `json:"city"`
		YearsInNeighborhood *int      `json:"years_in_neighborhood"`
		ProfessionalBio     *string   `json:"professional_bio"`
		CategorySlugs       *[]string `json:"category_slugs"`
		NeedsTransport      *bool     `json:"needs_transport"`
		TransportType       *string   `json:"transport_type"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	if err := h.svc.UpdateMe(r.Context(), claims.CommunityID, claims.UserID, service.UpdateProviderInput{
		City:                in.City,
		YearsInNeighborhood: in.YearsInNeighborhood,
		ProfessionalBio:     in.ProfessionalBio,
		CategorySlugs:       in.CategorySlugs,
		NeedsTransport:      in.NeedsTransport,
		TransportType:       in.TransportType,
	}); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ProviderHandler) AddPhoto(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	var in struct {
		S3Key   string `json:"s3_key"`
		Caption string `json:"caption"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	if err := h.svc.AddPhoto(r.Context(), claims.CommunityID, claims.UserID, in.S3Key, in.Caption); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

func (h *ProviderHandler) DeletePhoto(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	photoID, err := uuid.Parse(chi.URLParam(r, "photoID"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	if err := h.svc.DeletePhoto(r.Context(), claims.UserID, photoID); err != nil {
		jsonError(w, "not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ProviderHandler) Dashboard(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	stats, err := h.analytics.DashboardSummary(r.Context(), claims.CommunityID, claims.UserID)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonOK(w, stats)
}

// HireCompleted — morador confirma contratação de um prestador
func (h *ProviderHandler) HireCompleted(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	providerID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	if err := h.analytics.HireCompleted(r.Context(), claims.CommunityID, providerID, claims.UserID, h.svc); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonOK(w, map[string]string{"status": "ok"})
}
