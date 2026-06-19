CREATE TYPE doc_status AS ENUM ('pending', 'under_review', 'approved', 'rejected');

CREATE TABLE provider_profiles (
    user_id               UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    community_id          UUID NOT NULL REFERENCES communities(id),
    city                  TEXT NOT NULL,
    years_in_neighborhood SMALLINT NOT NULL DEFAULT 0,
    professional_bio      TEXT,
    score_aldeia          NUMERIC(5,2) NOT NULL DEFAULT 0,
    total_clients         INT NOT NULL DEFAULT 0,
    total_hires           INT NOT NULL DEFAULT 0,
    recommendation_count  INT NOT NULL DEFAULT 0,
    avg_rating            NUMERIC(3,2),
    doc_status            doc_status NOT NULL DEFAULT 'pending',
    doc_cpf_key           TEXT,
    doc_id_key            TEXT,
    is_visible            BOOLEAN NOT NULL DEFAULT false,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_provider_profiles_community ON provider_profiles(community_id);
CREATE INDEX idx_provider_profiles_score ON provider_profiles(community_id, score_aldeia DESC) WHERE is_visible = true;
CREATE INDEX idx_provider_profiles_rating ON provider_profiles(community_id, avg_rating DESC) WHERE is_visible = true;

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
