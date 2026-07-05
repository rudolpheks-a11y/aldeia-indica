ALTER TABLE provider_profiles ADD COLUMN total_hires INT NOT NULL DEFAULT 0;

CREATE TABLE provider_hires (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id  UUID NOT NULL REFERENCES communities(id),
    provider_id   UUID NOT NULL REFERENCES users(id),
    hirer_id      UUID NOT NULL REFERENCES users(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(community_id, provider_id, hirer_id)
);

CREATE INDEX idx_provider_hires_provider ON provider_hires(provider_id);
