CREATE TABLE provider_availability (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    community_id UUID NOT NULL REFERENCES communities(id),
    day_of_week  SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Dom … 6=Sáb
    start_time   TEXT NOT NULL, -- "08:00"
    end_time     TEXT NOT NULL, -- "18:00"
    UNIQUE (provider_id, day_of_week)
);
CREATE INDEX idx_provider_availability_provider ON provider_availability(provider_id);
