package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
)

type AdminHandler struct {
	db *pgxpool.Pool
}

func NewAdminHandler(db *pgxpool.Pool) *AdminHandler {
	return &AdminHandler{db: db}
}

func (h *AdminHandler) ListUsers(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	status := r.URL.Query().Get("status")

	query := `SELECT id, full_name, email, role, status, created_at
	           FROM users WHERE community_id=$1`
	args := []any{claims.CommunityID}

	if status != "" {
		query += " AND status=$2 ORDER BY created_at DESC"
		args = append(args, status)
	} else {
		query += " ORDER BY created_at DESC"
	}

	rows, err := h.db.Query(r.Context(), query, args...)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var users []map[string]any
	for rows.Next() {
		var u struct {
			ID        uuid.UUID `json:"id"`
			FullName  string    `json:"full_name"`
			Email     string    `json:"email"`
			Role      string    `json:"role"`
			Status    string    `json:"status"`
			CreatedAt string    `json:"created_at"`
		}
		rows.Scan(&u.ID, &u.FullName, &u.Email, &u.Role, &u.Status, &u.CreatedAt)
		users = append(users, map[string]any{
			"id": u.ID, "full_name": u.FullName, "email": u.Email,
			"role": u.Role, "status": u.Status, "created_at": u.CreatedAt,
		})
	}
	jsonOK(w, users)
}

func (h *AdminHandler) UpdateUserStatus(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	userID, err := uuid.Parse(chi.URLParam(r, "id"))
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

	_, err = h.db.Exec(r.Context(),
		`UPDATE users SET status=$1 WHERE id=$2 AND community_id=$3`,
		in.Status, userID, claims.CommunityID,
	)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *AdminHandler) ListDocumentQueue(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	rows, err := h.db.Query(r.Context(),
		`SELECT u.id, u.full_name, u.email, pp.doc_status, pp.doc_cpf_key, pp.doc_id_key
		 FROM provider_profiles pp JOIN users u ON u.id = pp.user_id
		 WHERE pp.community_id=$1 AND pp.doc_status IN ('pending','under_review')
		 ORDER BY u.created_at ASC`,
		claims.CommunityID,
	)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var queue []map[string]any
	for rows.Next() {
		var item struct {
			UserID    uuid.UUID `json:"user_id"`
			FullName  string    `json:"full_name"`
			Email     string    `json:"email"`
			DocStatus string    `json:"doc_status"`
			DocCPF    *string   `json:"doc_cpf_key"`
			DocID     *string   `json:"doc_id_key"`
		}
		rows.Scan(&item.UserID, &item.FullName, &item.Email, &item.DocStatus, &item.DocCPF, &item.DocID)
		queue = append(queue, map[string]any{
			"user_id": item.UserID, "full_name": item.FullName, "email": item.Email,
			"doc_status": item.DocStatus, "doc_cpf_key": item.DocCPF, "doc_id_key": item.DocID,
		})
	}
	jsonOK(w, queue)
}

func (h *AdminHandler) ReviewDocument(w http.ResponseWriter, r *http.Request) {
	providerID, err := uuid.Parse(chi.URLParam(r, "providerID"))
	if err != nil {
		jsonError(w, "invalid id", http.StatusBadRequest)
		return
	}

	var in struct {
		Approve bool   `json:"approve"`
		Notes   string `json:"notes"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}

	status := "rejected"
	if in.Approve {
		status = "approved"
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback(r.Context())

	_, err = tx.Exec(r.Context(),
		`UPDATE provider_profiles SET doc_status=$1, is_visible=$2 WHERE user_id=$3`,
		status, in.Approve, providerID,
	)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}

	if in.Approve {
		_, err = tx.Exec(r.Context(),
			`UPDATE users SET status='active' WHERE id=$1`, providerID)
		if err != nil {
			jsonError(w, "internal error", http.StatusInternalServerError)
			return
		}
	}

	if err := tx.Commit(r.Context()); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// CreateCommunity — superadmin creates a new community (no community_id scope needed)
func (h *AdminHandler) CreateCommunity(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Name  string `json:"name"`
		Slug  string `json:"slug"`
		City  string `json:"city"`
		State string `json:"state"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}
	if in.Name == "" || in.Slug == "" {
		jsonError(w, "name and slug required", http.StatusBadRequest)
		return
	}

	var id uuid.UUID
	err := h.db.QueryRow(r.Context(),
		`INSERT INTO communities (name, slug, city, state) VALUES ($1,$2,$3,$4) RETURNING id`,
		in.Name, in.Slug, in.City, in.State,
	).Scan(&id)
	if err != nil {
		jsonError(w, "community already exists or db error", http.StatusConflict)
		return
	}
	jsonOK(w, map[string]string{"id": id.String(), "slug": in.Slug})
}

// ListCommunities — returns all active communities (public, used on login screen)
func (h *AdminHandler) ListCommunities(w http.ResponseWriter, r *http.Request) {
	rows, err := h.db.Query(r.Context(),
		`SELECT id, name, slug, city, state FROM communities WHERE is_active = true ORDER BY name`)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var list []map[string]any
	for rows.Next() {
		var c struct {
			ID    uuid.UUID
			Name  string
			Slug  string
			City  string
			State string
		}
		rows.Scan(&c.ID, &c.Name, &c.Slug, &c.City, &c.State)
		list = append(list, map[string]any{
			"id": c.ID, "name": c.Name, "slug": c.Slug, "city": c.City, "state": c.State,
		})
	}
	if list == nil {
		list = []map[string]any{}
	}
	jsonOK(w, list)
}
