CREATE TABLE provider_events (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES communities(id),
    provider_id  UUID NOT NULL REFERENCES provider_profiles(user_id),
    actor_id     UUID REFERENCES users(id),
    event_type   TEXT NOT NULL,
    metadata     JSONB,
    occurred_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_provider_events_provider ON provider_events(community_id, provider_id, occurred_at DESC);
CREATE INDEX idx_provider_events_type ON provider_events(community_id, event_type, occurred_at DESC);
