CREATE TABLE ratings (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES communities(id),
    provider_id  UUID NOT NULL REFERENCES provider_profiles(user_id),
    rater_id     UUID NOT NULL REFERENCES users(id),
    quality      SMALLINT NOT NULL CHECK (quality BETWEEN 1 AND 5),
    punctuality  SMALLINT NOT NULL CHECK (punctuality BETWEEN 1 AND 5),
    politeness   SMALLINT NOT NULL CHECK (politeness BETWEEN 1 AND 5),
    reliability  SMALLINT NOT NULL CHECK (reliability BETWEEN 1 AND 5),
    comment      TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (community_id, provider_id, rater_id)
);

CREATE INDEX idx_ratings_provider ON ratings(community_id, provider_id, created_at DESC);
