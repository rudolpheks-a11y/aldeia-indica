CREATE TABLE service_categories (
    id         SMALLSERIAL PRIMARY KEY,
    slug       TEXT NOT NULL UNIQUE,
    name_pt    TEXT NOT NULL,
    icon_name  TEXT,
    sort_order SMALLINT NOT NULL DEFAULT 0
);

CREATE TABLE provider_services (
    provider_id  UUID NOT NULL REFERENCES provider_profiles(user_id) ON DELETE CASCADE,
    category_id  SMALLINT NOT NULL REFERENCES service_categories(id),
    community_id UUID NOT NULL REFERENCES communities(id),
    PRIMARY KEY (provider_id, category_id)
);

CREATE INDEX idx_provider_services_category ON provider_services(community_id, category_id);
