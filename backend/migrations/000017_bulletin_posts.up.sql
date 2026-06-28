CREATE TABLE bulletin_posts (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID        NOT NULL REFERENCES communities(id),
    author_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content      TEXT        NOT NULL CHECK (char_length(content) BETWEEN 1 AND 1000),
    status       TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
    approved_by  UUID        REFERENCES users(id),
    approved_at  TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_bulletin_community_status ON bulletin_posts(community_id, status);
