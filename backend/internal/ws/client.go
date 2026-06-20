package ws

import (
	"context"
	"encoding/json"
	"log/slog"

	"github.com/coder/websocket"
	"github.com/google/uuid"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/domain"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/fcm"
	"github.com/rudolpheks-a11y/aldeia-indica/backend/internal/service"
)

// Client wraps a single WebSocket connection for one authenticated user.
type Client struct {
	conn        *websocket.Conn
	hub         *Hub
	chatSvc     *service.ChatService
	fcmSvc      *fcm.Client
	log         *slog.Logger
	userID      uuid.UUID
	communityID uuid.UUID
	outbound    chan []byte
}

func NewClient(
	conn *websocket.Conn,
	hub *Hub,
	chatSvc *service.ChatService,
	fcmSvc *fcm.Client,
	log *slog.Logger,
	userID, communityID uuid.UUID,
) *Client {
	return &Client{
		conn:        conn,
		hub:         hub,
		chatSvc:     chatSvc,
		fcmSvc:      fcmSvc,
		log:         log,
		userID:      userID,
		communityID: communityID,
		outbound:    make(chan []byte, 64),
	}
}

// enqueue puts data on the write queue (non-blocking; drops if full).
func (c *Client) enqueue(data []byte) {
	select {
	case c.outbound <- data:
	default:
		c.log.Warn("ws outbound queue full, dropping", "user", c.userID)
	}
}

// Run registers the client, starts the write pump, runs the read loop, then unregisters.
func (c *Client) Run(ctx context.Context) {
	c.hub.Register(c.userID, c)
	defer c.hub.Unregister(c.userID, c)

	writeCtx, cancelWrite := context.WithCancel(ctx)
	defer cancelWrite()
	go c.writeLoop(writeCtx)

	c.readLoop(ctx)
}

func (c *Client) readLoop(ctx context.Context) {
	defer close(c.outbound)
	for {
		_, raw, err := c.conn.Read(ctx)
		if err != nil {
			return
		}
		var frame domain.WSMessage
		if err := json.Unmarshal(raw, &frame); err != nil {
			c.log.Warn("ws bad json frame", "error", err)
			continue
		}
		switch frame.Type {
		case "message":
			c.handleMessage(ctx, frame)
		case "read":
			c.handleRead(ctx, frame)
		}
	}
}

func (c *Client) writeLoop(ctx context.Context) {
	for data := range c.outbound {
		if err := c.conn.Write(ctx, websocket.MessageText, data); err != nil {
			return
		}
	}
}

func (c *Client) handleMessage(ctx context.Context, frame domain.WSMessage) {
	convID, err := uuid.Parse(frame.ConversationID)
	if err != nil {
		return
	}

	msg := &domain.Message{
		ConversationID: convID,
		SenderID:       c.userID,
	}
	switch {
	case frame.MediaKey != nil:
		msg.Type = "image"
		msg.MediaKey = frame.MediaKey
	case frame.Lat != nil:
		msg.Type = "location"
		msg.Lat = frame.Lat
		msg.Lng = frame.Lng
	default:
		msg.Type = "text"
		msg.Body = frame.Body
	}

	if err := c.chatSvc.PersistMessage(ctx, msg); err != nil {
		c.log.Error("ws persist message", "error", err)
		return
	}

	out, _ := json.Marshal(msg)
	// Echo to sender
	c.enqueue(out)
	// Deliver to recipient if online
	pA, pB, err := c.chatSvc.ListParticipants(ctx, convID)
	if err != nil {
		c.log.Error("ws list participants", "error", err)
		return
	}
	recipientID := pA
	if pA == c.userID {
		recipientID = pB
	}
	c.hub.Send(recipientID, out)

	// Push notification if recipient is offline
	if !c.hub.IsOnline(recipientID) {
		go c.pushNotify(recipientID, msg)
	}
}

func (c *Client) handleRead(ctx context.Context, frame domain.WSMessage) {
	convID, err := uuid.Parse(frame.ConversationID)
	if err != nil {
		return
	}
	if err := c.chatSvc.MarkRead(ctx, convID, c.userID); err != nil {
		c.log.Error("ws mark read", "error", err)
		return
	}
	readFrame, _ := json.Marshal(map[string]string{
		"type":            "read",
		"conversation_id": frame.ConversationID,
		"reader_id":       c.userID.String(),
	})
	pA, pB, _ := c.chatSvc.ListParticipants(ctx, convID)
	other := pA
	if pA == c.userID {
		other = pB
	}
	c.hub.Send(other, readFrame)
}

func (c *Client) pushNotify(recipientID uuid.UUID, msg *domain.Message) {
	tokens, err := c.chatSvc.GetDeviceTokens(context.Background(), recipientID)
	if err != nil || len(tokens) == 0 {
		return
	}
	body := "[Imagem]"
	if msg.Body != nil {
		body = *msg.Body
	}
	c.fcmSvc.SendMulti(context.Background(), tokens, fcm.Notification{
		Title: "Nova mensagem",
		Body:  body,
	})
}
