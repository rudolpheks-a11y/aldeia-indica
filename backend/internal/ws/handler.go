package ws

import (
	"log/slog"
	"net/http"

	"github.com/coder/websocket"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/auth"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/fcm"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
)

type Handler struct {
	hub     *Hub
	chatSvc *service.ChatService
	fcmSvc  *fcm.Client
	jwt     *auth.JWT
	log     *slog.Logger
}

func NewHandler(hub *Hub, chatSvc *service.ChatService, fcmSvc *fcm.Client, j *auth.JWT, log *slog.Logger) *Handler {
	return &Handler{hub: hub, chatSvc: chatSvc, fcmSvc: fcmSvc, jwt: j, log: log}
}

// ServeHTTP handles GET /ws/chat?token=<jwt>
// The JWT is a query parameter because the browser WebSocket API cannot set headers.
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	if token == "" {
		http.Error(w, "missing token", http.StatusUnauthorized)
		return
	}
	claims, err := h.jwt.Parse(token)
	if err != nil {
		http.Error(w, "invalid token", http.StatusUnauthorized)
		return
	}

	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		OriginPatterns: []string{"*"},
	})
	if err != nil {
		h.log.Error("ws accept", "error", err)
		return
	}
	defer conn.CloseNow()

	c := NewClient(conn, h.hub, h.chatSvc, h.fcmSvc, h.log, claims.UserID, claims.CommunityID)
	h.log.Info("ws connected", "user", claims.UserID)
	c.Run(r.Context())
	h.log.Info("ws disconnected", "user", claims.UserID)
}
