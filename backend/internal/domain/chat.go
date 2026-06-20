package domain

import (
	"time"

	"github.com/google/uuid"
)

type MessageType string

const (
	MessageText     MessageType = "text"
	MessageImage    MessageType = "image"
	MessageLocation MessageType = "location"
)

type Conversation struct {
	ID             uuid.UUID
	CommunityID    uuid.UUID
	ParticipantA   uuid.UUID
	ParticipantB   uuid.UUID
	LastMessageAt  *time.Time
	CreatedAt      time.Time
}

type Message struct {
	ID             uuid.UUID   `json:"id"`
	ConversationID uuid.UUID   `json:"conversation_id"`
	SenderID       uuid.UUID   `json:"sender_id"`
	Type           string      `json:"type"`
	Body           *string     `json:"body,omitempty"`
	MediaKey       *string     `json:"media_key,omitempty"`
	Lat            *float64    `json:"lat,omitempty"`
	Lng            *float64    `json:"lng,omitempty"`
	ReadAt         *time.Time  `json:"read_at,omitempty"`
	CreatedAt      time.Time   `json:"created_at"`
}

// WSMessage is the JSON frame sent over WebSocket.
type WSMessage struct {
	Type           string   `json:"type"`
	ConversationID string   `json:"conversation_id,omitempty"`
	Body           *string  `json:"body,omitempty"`
	MediaKey       *string  `json:"media_key,omitempty"`
	Lat            *float64 `json:"lat,omitempty"`
	Lng            *float64 `json:"lng,omitempty"`
}
