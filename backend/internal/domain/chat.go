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
	ID             uuid.UUID
	ConversationID uuid.UUID
	CommunityID    uuid.UUID
	SenderID       uuid.UUID
	Type           MessageType
	Body           *string
	ReadAt         *time.Time
	CreatedAt      time.Time
}

// WSMessage is the JSON frame sent over WebSocket.
type WSMessage struct {
	Type           string     `json:"type"`
	ConversationID string     `json:"conversation_id,omitempty"`
	ID             string     `json:"id,omitempty"`
	SenderID       string     `json:"sender_id,omitempty"`
	Body           string     `json:"body,omitempty"`
	MediaKey       string     `json:"media_key,omitempty"`
	Lat            float64    `json:"lat,omitempty"`
	Lng            float64    `json:"lng,omitempty"`
	CreatedAt      *time.Time `json:"created_at,omitempty"`
}
