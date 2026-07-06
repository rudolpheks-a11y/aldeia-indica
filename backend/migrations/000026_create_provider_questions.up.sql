CREATE TABLE provider_questions (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES communities(id),
    provider_id  UUID NOT NULL REFERENCES provider_profiles(user_id) ON DELETE CASCADE,
    asker_id     UUID NOT NULL REFERENCES users(id),
    question     TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_provider_questions_provider ON provider_questions(provider_id, created_at DESC);

CREATE TABLE provider_question_answers (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id  UUID NOT NULL REFERENCES provider_questions(id) ON DELETE CASCADE,
    community_id UUID NOT NULL REFERENCES communities(id),
    responder_id UUID NOT NULL REFERENCES users(id),
    answer       TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_provider_question_answers_question ON provider_question_answers(question_id, created_at ASC);
