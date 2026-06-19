CREATE TYPE approval_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE approval_method AS ENUM ('resident_vote', 'admin', 'invite');

CREATE TABLE user_approvals (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES communities(id),
    applicant_id UUID NOT NULL REFERENCES users(id),
    status       approval_status NOT NULL DEFAULT 'pending',
    method       approval_method,
    resolved_by  UUID REFERENCES users(id),
    resolved_at  TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_approvals_community ON user_approvals(community_id, status);

CREATE TABLE approval_votes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_id UUID NOT NULL REFERENCES user_approvals(id),
    voter_id    UUID NOT NULL REFERENCES users(id),
    community_id UUID NOT NULL REFERENCES communities(id),
    voted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (approval_id, voter_id)
);

CREATE TABLE invites (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id   UUID NOT NULL REFERENCES communities(id),
    created_by     UUID NOT NULL REFERENCES users(id),
    token          TEXT NOT NULL UNIQUE,
    intended_email TEXT,
    used_by        UUID REFERENCES users(id),
    used_at        TIMESTAMPTZ,
    expires_at     TIMESTAMPTZ NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_invites_token ON invites(token);
