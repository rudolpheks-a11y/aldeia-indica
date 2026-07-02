package email

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"
)

const httpTimeout = 10 * time.Second

type Client struct {
	apiKey string
	from   string
	http   *http.Client
	log    *slog.Logger
}

// New creates a Resend email client.
// Returns a no-op client if apiKey is empty (dev without email configured).
func New(apiKey, from string, log *slog.Logger) *Client {
	if apiKey == "" {
		log.Warn("email not configured — password reset emails disabled")
	}
	return &Client{apiKey: apiKey, from: from, http: &http.Client{Timeout: httpTimeout}, log: log}
}

type Message struct {
	To      string
	Subject string
	HTML    string
}

func (c *Client) Send(ctx context.Context, m Message) error {
	if c.apiKey == "" {
		c.log.Info("email send skipped (not configured)", "to", m.To, "subject", m.Subject)
		return nil
	}

	payload := map[string]any{
		"from":    c.from,
		"to":      []string{m.To},
		"subject": m.Subject,
		"html":    m.HTML,
	}
	body, _ := json.Marshal(payload)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.resend.com/emails", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("resend send: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("resend http %d: %s", resp.StatusCode, string(b))
	}
	return nil
}
