CREATE TYPE user_role AS ENUM ('morador', 'prestador', 'admin');
CREATE TYPE user_status AS ENUM ('pending', 'active', 'suspended');

CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id  UUID NOT NULL REFERENCES communities(id),
    email         TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    role          user_role NOT NULL,
    status        user_status NOT NULL DEFAULT 'pending',
    full_name     TEXT NOT NULL,
    avatar_key    TEXT,
    phone         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (community_id, email)
);

CREATE INDEX idx_users_community ON users(community_id);
CREATE INDEX idx_users_email ON users(email);

CREATE TABLE morador_profiles (
    user_id            UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    community_id       UUID NOT NULL REFERENCES communities(id),
    street_address     TEXT NOT NULL,
    house_number       TEXT NOT NULL,
    neighborhood_block TEXT,
    verified_resident  BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE refresh_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  TEXT NOT NULL UNIQUE,
    device_info TEXT,
    expires_at  TIMESTAMPTZ NOT NULL,
    revoked_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);

CREATE TABLE device_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fcm_token  TEXT NOT NULL,
    platform   TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, platform)
);
