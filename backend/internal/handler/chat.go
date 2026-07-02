package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/domain"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/server/middleware"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
)

type ChatHandler struct {
	svc       *service.ChatService
	analytics *service.AnalyticsService
}

func NewChatHandler(svc *service.ChatService, analytics *service.AnalyticsService) *ChatHandler {
	return &ChatHandler{svc: svc, analytics: analytics}
}

// POST /chat/conversations — get or create a conversation with another user
func (h *ChatHandler) GetOrCreate(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())

	var in struct {
		OtherUserID string `json:"other_user_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		jsonError(w, "invalid body", http.StatusBadRequest)
		return
	}
	otherID, err := uuid.Parse(in.OtherUserID)
	if err != nil {
		jsonError(w, "invalid other_user_id", http.StatusBadRequest)
		return
	}
	if otherID == claims.UserID {
		jsonError(w, "cannot chat with yourself", http.StatusBadRequest)
		return
	}

	conv, err := h.svc.GetOrCreateConversation(r.Context(), claims.CommunityID, claims.UserID, otherID)
	if err != nil {
		if errors.Is(err, service.ErrCrossCommunity) {
			jsonError(w, "user does not belong to your community", http.StatusForbidden)
			return
		}
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}

	// Record contact_initiated if the other user is a provider
	actorID := claims.UserID
	go h.analytics.RecordEvent(r.Context(), claims.CommunityID, otherID, &actorID, service.EventContactInitiated)

	jsonOK(w, conv)
}

// GET /chat/conversations
func (h *ChatHandler) ListConversations(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	list, err := h.svc.ListConversations(r.Context(), claims.CommunityID, claims.UserID)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	if list == nil {
		list = []service.ConversationSummary{}
	}
	jsonOK(w, list)
}

// GET /chat/conversations/{id}/messages
func (h *ChatHandler) ListMessages(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	convID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid conversation id", http.StatusBadRequest)
		return
	}

	if err := h.assertParticipant(r.Context(), w, convID, claims.UserID); err != nil {
		return
	}

	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	msgs, err := h.svc.LoadHistory(r.Context(), convID, 50, page*50)
	if err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	if msgs == nil {
		msgs = []domain.Message{}
	}
	jsonOK(w, msgs)
}

// POST /chat/conversations/{id}/read
func (h *ChatHandler) MarkRead(w http.ResponseWriter, r *http.Request) {
	claims, _ := middleware.ClaimsFrom(r.Context())
	convID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		jsonError(w, "invalid conversation id", http.StatusBadRequest)
		return
	}
	if err := h.assertParticipant(r.Context(), w, convID, claims.UserID); err != nil {
		return
	}
	if err := h.svc.MarkRead(r.Context(), convID, claims.UserID); err != nil {
		jsonError(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// assertParticipant confirms the conversation exists (404 otherwise) and that
// userID is one of its two participants (403 otherwise). Writes the error
// response itself and returns a non-nil error when the caller should stop.
func (h *ChatHandler) assertParticipant(ctx context.Context, w http.ResponseWriter, convID, userID uuid.UUID) error {
	pA, pB, err := h.svc.ListParticipants(ctx, convID)
	if err != nil {
		jsonError(w, "not found", http.StatusNotFound)
		return err
	}
	if userID != pA && userID != pB {
		jsonError(w, "forbidden", http.StatusForbidden)
		return errors.New("not a participant")
	}
	return nil
}
