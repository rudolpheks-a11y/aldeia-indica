package handler

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
)

type CategoryHandler struct {
	db *pgxpool.Pool
}

func NewCategoryHandler(db *pgxpool.Pool) *CategoryHandler {
	return &CategoryHandler{db: db}
}

func (h *CategoryHandler) List(w http.ResponseWriter, r *http.Request) {
	rows, err := h.db.Query(r.Context(),
		`SELECT id, slug, name_pt, icon_name FROM service_categories ORDER BY sort_order`)
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
		rows.Scan(&id, &slug, &name, &icon)
		cats = append(cats, map[string]any{"id": id, "slug": slug, "name_pt": name, "icon_name": icon})
	}
	jsonOK(w, cats)
}
