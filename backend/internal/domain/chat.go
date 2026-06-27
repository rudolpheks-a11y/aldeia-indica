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
	ID            uuid.UUID  `json:"id"`
	CommunityID   uuid.UUID  `json:"community_id"`
	ParticipantA  uuid.UUID  `json:"participant_a"`
	ParticipantB  uuid.UUID  `json:"participant_b"`
	LastMessageAt *time.Time `json:"last_message_at"`
	CreatedAt     time.Time  `json:"created_at"`
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
