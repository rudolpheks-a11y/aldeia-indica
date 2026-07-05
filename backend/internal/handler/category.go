package handler

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
)

type CategoryHandler struct {
	db *pgxpool.Pool
}

func NewCategoryHandler(db *pgxpool.Pool) *CategoryHandler {
	return &CategoryHandler{db: db}
}

// List retorna as categorias de serviço com a contagem de prestadores
// visíveis por categoria, escopada pela comunidade do chamador — calculada
// no banco (COUNT), em vez do mobile buscar até 200 prestadores e recontar
// por nome no cliente.
func (h *CategoryHandler) List(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	rows, err := h.db.Query(r.Context(), `
		SELECT sc.id, sc.slug, sc.name_pt, sc.icon_name,
		       (SELECT COUNT(DISTINCT ps.provider_id) FROM provider_services ps
		        JOIN provider_profiles pp ON pp.user_id = ps.provider_id
		        JOIN users u ON u.id = pp.user_id
		        WHERE ps.category_id = sc.id AND ps.community_id = $1
		          AND pp.is_visible = true AND u.status = 'active') AS provider_count
		FROM service_categories sc
		ORDER BY sc.sort_order`,
		claims.CommunityID,
	)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var cats []map[string]any
	for rows.Next() {
		var id int
		var slug, name string
		var icon *string
		var providerCount int
		if err := rows.Scan(&id, &slug, &name, &icon, &providerCount); err != nil {
			jsonError(w, "internal error", http.StatusInternalServerError)
			return
		}
		cats = append(cats, map[string]any{
			"id": id, "slug": slug, "name_pt": name, "icon_name": icon,
			"provider_count": providerCount,
		})
	}
	if err := rows.Err(); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonOK(w, cats)
}
