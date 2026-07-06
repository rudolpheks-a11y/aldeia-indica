CREATE TABLE provider_favorites (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES communities(id),
    morador_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider_id  UUID NOT NULL REFERENCES provider_profiles(user_id) ON DELETE CASCADE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (community_id, morador_id, provider_id)
);
CREATE INDEX idx_provider_favorites_morador ON provider_favorites(morador_id, created_at DESC);
