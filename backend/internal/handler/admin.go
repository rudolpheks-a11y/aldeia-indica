package handler

import (
	"encoding/json"
	"fmt"
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
		AvisosPendentes         int `json:"avisos_pendentes"`
	}

	err := h.db.QueryRow(r.Context(), `
		SELECT
			(SELECT COUNT(*) FROM users WHERE community_id=$1 AND role='morador' AND deleted_at IS NULL),
			(SELECT COUNT(*) FROM users WHERE community_id=$1 AND role='morador' AND status='active' AND deleted_at IS NULL),
			(SELECT COUNT(*) FROM users WHERE community_id=$1 AND role='prestador' AND deleted_at IS NULL),
			(SELECT COUNT(*) FROM users WHERE community_id=$1 AND role='prestador' AND status='active' AND deleted_at IS NULL),
			(SELECT COUNT(*) FROM service_categories),
			(SELECT COUNT(*) FROM provider_services WHERE community_id=$1),
			(SELECT COUNT(*) FROM service_requests WHERE community_id=$1),
			(SELECT COUNT(*) FROM ratings WHERE community_id=$1),
			(SELECT COUNT(*) FROM recommendations WHERE community_id=$1),
			(SELECT COUNT(*) FROM bulletin_posts WHERE community_id=$1 AND status='pending')
	`, claims.CommunityID).Scan(
		&s.TotalMoradores, &s.MoradoresAtivos,
		&s.TotalPrestadores, &s.PrestadoresAtivos,
		&s.TotalCategorias, &s.TotalServicosOferecidos,
		&s.TotalPedidos, &s.TotalAvaliacoes, &s.TotalRecomendacoes,
		&s.AvisosPendentes,
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
	role := r.URL.Query().Get("role")

	// LEFT JOIN: só prestadores têm provider_profiles; para moradores/admin
	// (e prestadores anteriores à exigência do aceite, 2026-07-12) o campo
	// ratings_acknowledged_at vem NULL — o app admin mostra "sem aceite".
	// ?deleted=true lista as contas EXCLUÍDAS. É a trilha antifraude: um
	// prestador pode excluir a conta pra tentar escapar de uma avaliação ruim,
	// e o admin precisa enxergar isso. `deleted_by <> u.id` distingue quem foi
	// removido pelo admin de quem se autoexcluiu.
	onlyDeleted := r.URL.Query().Get("deleted") == "true"
	deletedFilter := "u.deleted_at IS NULL"
	if onlyDeleted {
		deletedFilter = "u.deleted_at IS NOT NULL"
	}

	query := `SELECT u.id, u.full_name, u.email, u.role, u.status, u.created_at,
	                 pp.ratings_acknowledged_at, u.deleted_at,
	                 (u.deleted_by IS NOT NULL AND u.deleted_by <> u.id) AS deleted_by_admin
	           FROM users u
	           LEFT JOIN provider_profiles pp ON pp.user_id = u.id
	           WHERE u.community_id=$1 AND ` + deletedFilter
	args := []any{claims.CommunityID}

	if status != "" {
		args = append(args, status)
		query += fmt.Sprintf(" AND u.status=$%d", len(args))
	}
	if role != "" {
		args = append(args, role)
		query += fmt.Sprintf(" AND u.role=$%d", len(args))
	}
	query += " ORDER BY u.created_at DESC"

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
			// *time.Time, não time.Time: a coluna é nullable e um Scan em
			// tipo não-ponteiro falharia silenciosamente truncando a lista
			// (mesma classe do bug de admin/users corrigido em 2026-07-03).
			RatingsAcknowledgedAt *time.Time `json:"ratings_acknowledged_at"`
			DeletedAt             *time.Time `json:"deleted_at"`
			DeletedByAdmin        bool       `json:"deleted_by_admin"`
		}
		if err := rows.Scan(&u.ID, &u.FullName, &u.Email, &u.Role, &u.Status, &u.CreatedAt,
			&u.RatingsAcknowledgedAt, &u.DeletedAt, &u.DeletedByAdmin); err != nil {
			jsonError(w, "internal error", http.StatusInternalServerError)
			return
		}
		users = append(users, map[string]any{
			"id": u.ID, "full_name": u.FullName, "email": u.Email,
			"role": u.Role, "status": u.Status, "created_at": u.CreatedAt,
			"ratings_acknowledged_at": u.RatingsAcknowledgedAt,
			"deleted_at":              u.DeletedAt,
			"deleted_by_admin":        u.DeletedByAdmin,
		})
	}
	if err := rows.Err(); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	if users == nil {
		users = []map[string]any{}
	}
	jsonOK(w, users)
}

// ListProviderServices — quem oferece qual serviço, pra visão geral do admin.
func (h *AdminHandler) ListProviderServices(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	rows, err := h.db.Query(r.Context(), `
		SELECT u.full_name, sc.name_pt
		FROM provider_services ps
		JOIN users u ON u.id = ps.provider_id
		JOIN service_categories sc ON sc.id = ps.category_id
		WHERE ps.community_id = $1
		ORDER BY u.full_name, sc.name_pt`,
		claims.CommunityID,
	)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var result []map[string]any
	for rows.Next() {
		var providerName, categoryName string
		if err := rows.Scan(&providerName, &categoryName); err != nil {
			jsonError(w, "internal error", http.StatusInternalServerError)
			return
		}
		result = append(result, map[string]any{
			"provider_name": providerName, "category_name": categoryName,
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

// ListRatings — todas as avaliações da comunidade, pra visão geral do admin.
func (h *AdminHandler) ListRatings(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	rows, err := h.db.Query(r.Context(), `
		SELECT ru.full_name, pu.full_name, r.quality, r.punctuality, r.politeness, r.reliability, r.comment, r.created_at
		FROM ratings r
		JOIN users ru ON ru.id = r.rater_id
		JOIN users pu ON pu.id = r.provider_id
		WHERE r.community_id = $1
		ORDER BY r.created_at DESC LIMIT 200`,
		claims.CommunityID,
	)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var result []map[string]any
	for rows.Next() {
		var rater, provider string
		var quality, punctuality, politeness, reliability int
		var comment *string
		var createdAt time.Time
		if err := rows.Scan(&rater, &provider, &quality, &punctuality, &politeness, &reliability, &comment, &createdAt); err != nil {
			jsonError(w, "internal error", http.StatusInternalServerError)
			return
		}
		avg := float64(quality+punctuality+politeness+reliability) / 4
		result = append(result, map[string]any{
			"rater_name": rater, "provider_name": provider,
			"average": avg, "comment": comment, "created_at": createdAt,
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

// ListRecommendations — todas as indicações da comunidade, pra visão geral do admin.
func (h *AdminHandler) ListRecommendations(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	rows, err := h.db.Query(r.Context(), `
		SELECT ru.full_name, pu.full_name, rec.created_at
		FROM recommendations rec
		JOIN users ru ON ru.id = rec.recommender_id
		JOIN users pu ON pu.id = rec.provider_id
		WHERE rec.community_id = $1
		ORDER BY rec.created_at DESC LIMIT 200`,
		claims.CommunityID,
	)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var result []map[string]any
	for rows.Next() {
		var recommender, provider string
		var createdAt time.Time
		if err := rows.Scan(&recommender, &provider, &createdAt); err != nil {
			jsonError(w, "internal error", http.StatusInternalServerError)
			return
		}
		result = append(result, map[string]any{
			"recommender_name": recommender, "provider_name": provider, "created_at": createdAt,
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
		if err := rows.Scan(&c.ID, &c.Name, &c.Slug, &c.City, &c.State); err != nil {
			jsonError(w, "internal error", http.StatusInternalServerError)
			return
		}
		list = append(list, map[string]any{
			"id": c.ID, "name": c.Name, "slug": c.Slug, "city": c.City, "state": c.State,
		})
	}
	if err := rows.Err(); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	if list == nil {
		list = []map[string]any{}
	}
	jsonOK(w, list)
}
