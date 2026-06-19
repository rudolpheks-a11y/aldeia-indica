CREATE TYPE message_type AS ENUM ('text', 'image', 'location');

CREATE TABLE conversations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id    UUID NOT NULL REFERENCES communities(id),
    participant_a   UUID NOT NULL REFERENCES users(id),
    participant_b   UUID NOT NULL REFERENCES users(id),
    last_message_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (community_id, participant_a, participant_b),
    CHECK (participant_a < participant_b)
);

CREATE INDEX idx_conversations_a ON conversations(community_id, participant_a, last_message_at DESC);
CREATE INDEX idx_conversations_b ON conversations(community_id, participant_b, last_message_at DESC);

CREATE TABLE messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id),
    community_id    UUID NOT NULL REFERENCES communities(id),
    sender_id       UUID NOT NULL REFERENCES users(id),
    type            message_type NOT NULL DEFAULT 'text',
    body            TEXT,
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at DESC);
