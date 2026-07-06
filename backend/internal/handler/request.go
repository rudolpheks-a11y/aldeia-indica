package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/domain"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
)

type RequestHandler struct {
	db *pgxpool.Pool
}

func NewRequestHandler(db *pgxpool.Pool) *RequestHandler {
	return &RequestHandler{db: db}
}

func (h *RequestHandler) List(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	status := r.URL.Query().Get("status")
	if status == "" {
		status = "open"
	}

	query := `SELECT sr.id, sr.requester_id, u.full_name, sc.name_pt, sr.title, sr.description,
	                 sr.desired_date, sr.status, sr.created_at,
	                 (SELECT COUNT(*) FROM service_request_responses srr WHERE srr.request_id = sr.id)
	          FROM service_requests sr
	          JOIN users u ON u.id = sr.requester_id
	          LEFT JOIN service_categories sc ON sc.id = sr.category_id
	          WHERE sr.community_id=$1`
	args := []any{claims.CommunityID}
	// status=all é usado pela visão geral do admin, que quer ver pedidos em
	// qualquer estado — os chamadores normais (feed de morador/prestador)
	// sempre passam um status específico ou nada (default 'open').
	if status != "all" {
		args = append(args, status)
		query += " AND sr.status=$2"
	}
	query += " ORDER BY sr.created_at DESC LIMIT 50"

	rows, err := h.db.Query(r.Context(), query, args...)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var result []map[string]any
	for rows.Next() {
		var id, requesterID uuid.UUID
		var requester, category *string
		var title, description *string
		var desiredDate *time.Time
		var status string
		var createdAt time.Time
		var responseCount int
		if err := rows.Scan(&id, &requesterID, &requester, &category, &title, &description, &desiredDate, &status, &createdAt, &responseCount); err != nil {
			jsonError(w, "internal error", http.StatusInternalServerError)
			return
		}
		result = append(result, map[string]any{
			"id": id, "requester_id": requesterID, "requester": requester, "category": category,
			"title": title, "description": description,
			"desired_date": desiredDate, "status": status, "created_at": createdAt,
			"response_count": responseCount,
		})
	}
	if err := rows.Err(); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	if result == nil {
		result = []map[string]any{}
	}
	jsonOK(w, result)
}

func (h *RequestHandler) Create(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	var in struct {
		CategorySlug string `json:"category_slug"`
		Title        string `json:"title"`
		Description  string `json:"description"`
		DesiredDate  string `json:"desired_date"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	var id uuid.UUID
	err := h.db.QueryRow(r.Context(),
		`INSERT INTO service_requests (community_id, requester_id, category_id, title, description)
		 SELECT $1, $2, (SELECT id FROM service_categories WHERE slug=$3), $4, $5
		 RETURNING id`,
		claims.CommunityID, claims.UserID, in.CategorySlug, in.Title, in.Description,
	).Scan(&id)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
	jsonOK(w, map[string]string{"id": id.String()})
}

func (h *RequestHandler) Get(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	requestID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	var result map[string]any
	row := h.db.QueryRow(r.Context(),
		`SELECT sr.id, sr.requester_id, u.full_name, sc.name_pt, sr.title, sr.description, sr.status, sr.created_at
		 FROM service_requests sr
		 JOIN users u ON u.id = sr.requester_id
		 LEFT JOIN service_categories sc ON sc.id = sr.category_id
		 WHERE sr.id=$1 AND sr.community_id=$2`,
		requestID, claims.CommunityID,
	)
	var id, requesterID uuid.UUID
	var requester, category, title, description, status string
	var createdAt time.Time
	if err := row.Scan(&id, &requesterID, &requester, &category, &title, &description, &status, &createdAt); err != nil {
		jsonError(w, "not found", http.StatusNotFound)
		return
	}
	result = map[string]any{
		"id": id, "requester_id": requesterID, "requester": requester, "category": category,
		"title": title, "description": description, "status": status, "created_at": createdAt,
	}
	jsonOK(w, result)
}

func (h *RequestHandler) UpdateStatus(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	requestID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	var in struct {
		Status string `json:"status"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	tag, err := h.db.Exec(r.Context(),
		`UPDATE service_requests SET status=$1, updated_at=now()
		 WHERE id=$2 AND requester_id=$3 AND community_id=$4`,
		in.Status, requestID, claims.UserID, claims.CommunityID,
	)
	if err != nil {
		jsonError(w, "invalid status", http.StatusBadRequest)
		return
	}
	if tag.RowsAffected() == 0 {
		jsonError(w, "request not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *RequestHandler) Respond(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	if claims.Role != domain.RolePrestador {
		jsonError(w, "forbidden", http.StatusForbidden)
		return
	}
	requestID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	var in struct {
		Message string `json:"message"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	// INSERT ... SELECT ties the insert to a request that actually belongs
	// to the caller's community and isn't the caller's own — a foreign
	// request_id, or one the caller authored, inserts zero rows.
	tag, err := h.db.Exec(r.Context(),
		`INSERT INTO service_request_responses (request_id, community_id, provider_id, message)
		 SELECT id, community_id, $2, $3 FROM service_requests
		 WHERE id=$1 AND community_id=$4 AND requester_id != $2`,
		requestID, claims.UserID, in.Message, claims.CommunityID,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			jsonError(w, "already responded", http.StatusConflict)
			return
		}
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	if tag.RowsAffected() == 0 {
		jsonError(w, "request not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

func (h *RequestHandler) ListResponses(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	requestID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	// Só quem publicou o pedido (ou um admin, para moderação) pode ver quem
	// respondeu — os prestadores que responderam não enxergam uns aos outros.
	if claims.Role != domain.RoleAdmin {
		var requesterID uuid.UUID
		err := h.db.QueryRow(r.Context(),
			`SELECT requester_id FROM service_requests WHERE id=$1 AND community_id=$2`,
			requestID, claims.CommunityID,
		).Scan(&requesterID)
		if err != nil {
			jsonError(w, "not found", http.StatusNotFound)
			return
		}
		if requesterID != claims.UserID {
			jsonError(w, "forbidden", http.StatusForbidden)
			return
		}
	}

	rows, err := h.db.Query(r.Context(),
		`SELECT u.id, u.full_name, srr.message, srr.created_at
		 FROM service_request_responses srr JOIN users u ON u.id = srr.provider_id
		 WHERE srr.request_id=$1 AND srr.community_id=$2 ORDER BY srr.created_at ASC`,
		requestID, claims.CommunityID,
	)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var result []map[string]any
	for rows.Next() {
		var providerID uuid.UUID
		var name, msg string
		var t time.Time
		if err := rows.Scan(&providerID, &name, &msg, &t); err != nil {
			jsonError(w, "internal error", http.StatusInternalServerError)
			return
		}
		result = append(result, map[string]any{
			"provider_id": providerID, "provider": name, "message": msg, "created_at": t,
		})
	}
	if err := rows.Err(); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	if result == nil {
		result = []map[string]any{}
	}
	jsonOK(w, result)
}
