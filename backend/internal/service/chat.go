package service

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/domain"
)

var ErrCrossCommunity = errors.New("other user does not belong to this community")

type ChatService struct {
	db *pgxpool.Pool
}

func NewChatService(db *pgxpool.Pool) *ChatService {
	return &ChatService{db: db}
}

// GetOrCreateConversation returns an existing conversation between two users or creates one.
// participant_a is always the smaller UUID to maintain the canonical ordering constraint.
func (s *ChatService) GetOrCreateConversation(ctx context.Context, communityID, userA, userB uuid.UUID) (*domain.Conversation, error) {
	// userB must belong to the caller's community — otherwise a user could
	// open a conversation with someone from another community just by
	// guessing/obtaining their user ID. (userA is always the caller, whose
	// community is already trusted from their own JWT claims.)
	var otherCommunity uuid.UUID
	if err := s.db.QueryRow(ctx,
		`SELECT community_id FROM users WHERE id = $1`, userB,
	).Scan(&otherCommunity); err != nil {
		return nil, err
	}
	if otherCommunity != communityID {
		return nil, ErrCrossCommunity
	}

	a, b := userA, userB
	if a.String() > b.String() {
		a, b = b, a
	}

	var conv domain.Conversation
	err := s.db.QueryRow(ctx,
		`SELECT id, community_id, participant_a, participant_b, created_at
		 FROM conversations WHERE community_id=$1 AND participant_a=$2 AND participant_b=$3`,
		communityID, a, b,
	).Scan(&conv.ID, &conv.CommunityID, &conv.ParticipantA, &conv.ParticipantB, &conv.CreatedAt)

	if err == nil {
		return &conv, nil
	}

	conv = domain.Conversation{
		ID:           uuid.New(),
		CommunityID:  communityID,
		ParticipantA: a,
		ParticipantB: b,
		CreatedAt:    time.Now(),
	}
	_, err = s.db.Exec(ctx,
		`INSERT INTO conversations (id, community_id, participant_a, participant_b)
		 VALUES ($1, $2, $3, $4)`,
		conv.ID, conv.CommunityID, conv.ParticipantA, conv.ParticipantB,
	)
	if err != nil {
		return nil, err
	}
	return &conv, nil
}

type ConversationSummary struct {
	ID           uuid.UUID  `json:"id"`
	OtherUserID  uuid.UUID  `json:"other_user_id"`
	OtherName    string     `json:"other_name"`
	OtherAvatar  *string    `json:"other_avatar"`
	LastBody     *string    `json:"last_body"`
	LastAt       *time.Time `json:"last_at"`
	UnreadCount  int        `json:"unread_count"`
}

func (s *ChatService) ListConversations(ctx context.Context, communityID, userID uuid.UUID) ([]ConversationSummary, error) {
	rows, err := s.db.Query(ctx, `
		SELECT
		    c.id,
		    CASE WHEN c.participant_a = $2 THEN c.participant_b ELSE c.participant_a END AS other_id,
		    u.full_name,
		    u.avatar_key,
		    (SELECT body FROM messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1),
		    (SELECT created_at FROM messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1),
		    (SELECT COUNT(*) FROM messages
		     WHERE conversation_id = c.id AND sender_id != $2 AND read_at IS NULL)
		FROM conversations c
		JOIN users u ON u.id = CASE WHEN c.participant_a = $2 THEN c.participant_b ELSE c.participant_a END
		WHERE c.community_id = $1
		  AND (c.participant_a = $2 OR c.participant_b = $2)
		ORDER BY (SELECT created_at FROM messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1) DESC NULLS LAST
	`, communityID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []ConversationSummary
	for rows.Next() {
		var s ConversationSummary
		if err := rows.Scan(&s.ID, &s.OtherUserID, &s.OtherName, &s.OtherAvatar, &s.LastBody, &s.LastAt, &s.UnreadCount); err != nil {
			return nil, err
		}
		list = append(list, s)
	}
	return list, rows.Err()
}

func (s *ChatService) LoadHistory(ctx context.Context, conversationID uuid.UUID, limit, offset int) ([]domain.Message, error) {
	if limit == 0 {
		limit = 50
	}
	rows, err := s.db.Query(ctx, `
		SELECT id, conversation_id, sender_id, type, body, media_key, lat, lng, read_at, created_at
		FROM messages
		WHERE conversation_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`, conversationID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var msgs []domain.Message
	for rows.Next() {
		var m domain.Message
		if err := rows.Scan(&m.ID, &m.ConversationID, &m.SenderID, &m.Type, &m.Body, &m.MediaKey, &m.Lat, &m.Lng, &m.ReadAt, &m.CreatedAt); err != nil {
			return nil, err
		}
		msgs = append(msgs, m)
	}
	return msgs, rows.Err()
}

func (s *ChatService) PersistMessage(ctx context.Context, msg *domain.Message) error {
	msg.ID = uuid.New()
	msg.CreatedAt = time.Now()
	_, err := s.db.Exec(ctx,
		`INSERT INTO messages (id, conversation_id, community_id, sender_id, type, body, media_key, lat, lng)
		 SELECT $1, $2, community_id, $3, $4, $5, $6, $7, $8 FROM conversations WHERE id = $2`,
		msg.ID, msg.ConversationID, msg.SenderID, msg.Type, msg.Body, msg.MediaKey, msg.Lat, msg.Lng,
	)
	return err
}

func (s *ChatService) MarkRead(ctx context.Context, conversationID, readerID uuid.UUID) error {
	_, err := s.db.Exec(ctx,
		`UPDATE messages SET read_at = now()
		 WHERE conversation_id = $1 AND sender_id != $2 AND read_at IS NULL`,
		conversationID, readerID,
	)
	return err
}

// ListParticipants returns both user IDs of a conversation (for routing push notifications).
func (s *ChatService) ListParticipants(ctx context.Context, conversationID uuid.UUID) (a, b uuid.UUID, err error) {
	err = s.db.QueryRow(ctx,
		`SELECT participant_a, participant_b FROM conversations WHERE id = $1`,
		conversationID,
	).Scan(&a, &b)
	return
}

// GetDeviceTokens returns FCM tokens for a user.
func (s *ChatService) GetDeviceTokens(ctx context.Context, userID uuid.UUID) ([]string, error) {
	rows, err := s.db.Query(ctx,
		`SELECT fcm_token FROM device_tokens WHERE user_id = $1`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var tokens []string
	for rows.Next() {
		var t string
		rows.Scan(&t)
		tokens = append(tokens, t)
	}
	return tokens, rows.Err()
}
