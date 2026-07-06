package handler

import (
	"net/http"

	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
)

type NotificationHandler struct {
	svc *service.NotificationService
}

func NewNotificationHandler(svc *service.NotificationService) *NotificationHandler {
	return &NotificationHandler{svc: svc}
}

func (h *NotificationHandler) List(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	list, err := h.svc.List(r.Context(), claims.UserID, 50)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	if list == nil {
		list = []service.NotificationRow{}
	}
	jsonOK(w, list)
}

func (h *NotificationHandler) UnreadCount(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	count, err := h.svc.UnreadCount(r.Context(), claims.UserID)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonOK(w, map[string]int{"count": count})
}

func (h *NotificationHandler) MarkAllRead(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	if err := h.svc.MarkAllRead(r.Context(), claims.UserID); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
