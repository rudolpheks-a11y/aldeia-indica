CREATE TABLE provider_photos (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id UUID NOT NULL REFERENCES provider_profiles(user_id) ON DELETE CASCADE,
    community_id UUID NOT NULL REFERENCES communities(id),
    s3_key      TEXT NOT NULL,
    caption     TEXT,
    sort_order  SMALLINT NOT NULL DEFAULT 0,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_provider_photos_provider ON provider_photos(provider_id);
