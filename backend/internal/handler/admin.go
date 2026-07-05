package handler

import (
	"encoding/json"
	"net/http"
	"time"

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

// Stats retorna uma visão geral da comunidade do admin — contagens usadas
// no dashboard do painel (moradores, prestadores, serviços, atividade).
// `service_categories` é o único número global (catálogo compartilhado
// entre comunidades); todo o resto é escopado por community_id.
func (h *AdminHandler) Stats(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	var s struct {
		TotalMoradores          int `json:"total_moradores"`
		MoradoresAtivos         int `json:"moradores_ativos"`
		TotalPrestadores        int `json:"total_prestadores"`
		PrestadoresAtivos       int `json:"prestadores_ativos"`
		TotalCategorias         int `json:"total_categorias"`
		TotalServicosOferecidos int `json:"total_servicos_oferecidos"`
		TotalPedidos            int `json:"total_pedidos"`
		TotalAvaliacoes         int `json:"total_avaliacoes"`
		TotalRecomendacoes      int `json:"total_recomendacoes"`
		TotalContratacoes       int `json:"total_contratacoes"`
		AvisosPendentes         int `json:"avisos_pendentes"`
	}

	err := h.db.QueryRow(r.Context(), `
		SELECT
			(SELECT COUNT(*) FROM users WHERE community_id=$1 AND role='morador'),
			(SELECT COUNT(*) FROM users WHERE community_id=$1 AND role='morador' AND status='active'),
			(SELECT COUNT(*) FROM users WHERE community_id=$1 AND role='prestador'),
			(SELECT COUNT(*) FROM users WHERE community_id=$1 AND role='prestador' AND status='active'),
			(SELECT COUNT(*) FROM service_categories),
			(SELECT COUNT(*) FROM provider_services WHERE community_id=$1),
			(SELECT COUNT(*) FROM service_requests WHERE community_id=$1),
			(SELECT COUNT(*) FROM ratings WHERE community_id=$1),
			(SELECT COUNT(*) FROM recommendations WHERE community_id=$1),
			(SELECT COUNT(*) FROM provider_hires WHERE community_id=$1),
			(SELECT COUNT(*) FROM bulletin_posts WHERE community_id=$1 AND status='pending')
	`, claims.CommunityID).Scan(
		&s.TotalMoradores, &s.MoradoresAtivos,
		&s.TotalPrestadores, &s.PrestadoresAtivos,
		&s.TotalCategorias, &s.TotalServicosOferecidos,
		&s.TotalPedidos, &s.TotalAvaliacoes, &s.TotalRecomendacoes,
		&s.TotalContratacoes, &s.AvisosPendentes,
	)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonOK(w, s)
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
			CreatedAt time.Time `json:"created_at"`
		}
		if err := rows.Scan(&u.ID, &u.FullName, &u.Email, &u.Role, &u.Status, &u.CreatedAt); err != nil {
			jsonError(w, "internal error", http.StatusInternalServerError)
			return
		}
		users = append(users, map[string]any{
			"id": u.ID, "full_name": u.FullName, "email": u.Email,
			"role": u.Role, "status": u.Status, "created_at": u.CreatedAt,
		})
	}
	if err := rows.Err(); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
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
