package ws

import (
	"sync"

	"github.com/google/uuid"
)

// Hub maintains active WebSocket connections keyed by user ID.
// A user may have multiple concurrent connections (multiple devices/tabs).
type Hub struct {
	mu      sync.RWMutex
	clients map[uuid.UUID]map[*Client]struct{}
}

func NewHub() *Hub {
	return &Hub{clients: make(map[uuid.UUID]map[*Client]struct{})}
}

func (h *Hub) Register(userID uuid.UUID, c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.clients[userID] == nil {
		h.clients[userID] = make(map[*Client]struct{})
	}
	h.clients[userID][c] = struct{}{}
}

func (h *Hub) Unregister(userID uuid.UUID, c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if set := h.clients[userID]; set != nil {
		delete(set, c)
		if len(set) == 0 {
			delete(h.clients, userID)
		}
	}
}

// Send delivers data to all connections belonging to userID.
func (h *Hub) Send(userID uuid.UUID, data []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for c := range h.clients[userID] {
		c.enqueue(data)
	}
}

// IsOnline reports whether userID has at least one active connection.
func (h *Hub) IsOnline(userID uuid.UUID) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients[userID]) > 0
}
