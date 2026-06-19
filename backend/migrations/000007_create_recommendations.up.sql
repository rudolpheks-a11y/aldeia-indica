CREATE TABLE recommendations (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id   UUID NOT NULL REFERENCES communities(id),
    provider_id    UUID NOT NULL REFERENCES provider_profiles(user_id),
    recommender_id UUID NOT NULL REFERENCES users(id),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (community_id, provider_id, recommender_id)
);

CREATE INDEX idx_recommendations_provider ON recommendations(community_id, provider_id);
