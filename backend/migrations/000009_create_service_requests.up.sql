CREATE TYPE request_status AS ENUM ('open', 'in_progress', 'closed');

CREATE TABLE service_requests (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES communities(id),
    requester_id UUID NOT NULL REFERENCES users(id),
    category_id  SMALLINT REFERENCES service_categories(id),
    title        TEXT NOT NULL,
    description  TEXT,
    desired_date DATE,
    desired_time TIME,
    status       request_status NOT NULL DEFAULT 'open',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_service_requests_community ON service_requests(community_id, status, created_at DESC);

CREATE TABLE service_request_responses (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id   UUID NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    community_id UUID NOT NULL REFERENCES communities(id),
    provider_id  UUID NOT NULL REFERENCES provider_profiles(user_id),
    message      TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (request_id, provider_id)
);
