-- Registra quem contratou quem, uma vez por par (morador, prestador) — mesma
-- semântica de UNIQUE(community_id, provider_id, rater_id) em ratings e
-- UNIQUE(community_id, provider_id, recommender_id) em recommendations.
-- Assume que "contratação confirmada" é um evento único por vizinho por
-- prestador, não recorrente — revisar se contratações repetidas devem contar
-- separadamente no futuro.
CREATE TABLE provider_hires (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id  UUID NOT NULL REFERENCES communities(id),
    provider_id   UUID NOT NULL REFERENCES users(id),
    hirer_id      UUID NOT NULL REFERENCES users(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(community_id, provider_id, hirer_id)
);

CREATE INDEX idx_provider_hires_provider ON provider_hires(provider_id);
