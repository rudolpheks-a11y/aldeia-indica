package fcm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

const fcmScope = "https://www.googleapis.com/auth/firebase.messaging"

const httpTimeout = 10 * time.Second

type Client struct {
	projectID   string
	tokenSource oauth2.TokenSource
	http        *http.Client
	log         *slog.Logger
}

// New creates an FCM client from a service account JSON (base64-decoded).
// Returns a no-op client if serviceAccountJSON is empty (dev without Firebase).
func New(ctx context.Context, serviceAccountJSON []byte, log *slog.Logger) (*Client, error) {
	if len(serviceAccountJSON) == 0 {
		log.Warn("FCM not configured — push notifications disabled")
		return &Client{log: log}, nil
	}

	creds, err := google.CredentialsFromJSON(ctx, serviceAccountJSON, fcmScope)
	if err != nil {
		return nil, fmt.Errorf("fcm credentials: %w", err)
	}

	// Extract project ID from the service account JSON.
	var sa struct {
		ProjectID string `json:"project_id"`
	}
	_ = json.Unmarshal(serviceAccountJSON, &sa)

	return &Client{
		projectID:   sa.ProjectID,
		tokenSource: creds.TokenSource,
		http:        &http.Client{Timeout: httpTimeout},
		log:         log,
	}, nil
}

type Notification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

// Send delivers a push notification to the given FCM registration token.
// Silently skips if the client has no credentials configured.
func (c *Client) Send(ctx context.Context, deviceToken string, n Notification) error {
	if c.tokenSource == nil {
		return nil
	}

	tok, err := c.tokenSource.Token()
	if err != nil {
		return fmt.Errorf("fcm token: %w", err)
	}

	payload := map[string]any{
		"message": map[string]any{
			"token": deviceToken,
			"notification": map[string]string{
				"title": n.Title,
				"body":  n.Body,
			},
		},
	}

	body, _ := json.Marshal(payload)
	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", c.projectID)
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+tok.AccessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("fcm send: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		b, _ := io.ReadAll(resp.Body)
		c.log.Error("fcm send failed", "status", resp.StatusCode, "body", string(b))
		return fmt.Errorf("fcm http %d", resp.StatusCode)
	}
	return nil
}

// SendMulti delivers to multiple device tokens, logging but not failing on individual errors.
func (c *Client) SendMulti(ctx context.Context, tokens []string, n Notification) {
	for _, t := range tokens {
		if err := c.Send(ctx, t, n); err != nil {
			c.log.Error("fcm send multi", "token_prefix", t[:min(8, len(t))], "error", err)
		}
	}
}
