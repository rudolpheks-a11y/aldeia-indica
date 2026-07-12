-- Exclusão de conta é soft-delete + anonimização, nunca DELETE físico.
-- A maioria das FKs para users(id) é RESTRICT (ratings, recommendations,
-- messages, service_requests, provider_questions): um DELETE seria bloqueado
-- pelo Postgres, e um ON DELETE CASCADE apagaria as avaliações e indicações
-- que a pessoa DEU a terceiros — mudando o Score Aldeia de quem ficou.
-- As linhas ficam, apontando para um usuário anonimizado.
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ;

-- Todo caminho de leitura (login, busca, listagem do admin) filtra por
-- deleted_at IS NULL — o índice parcial serve exatamente esse predicado.
CREATE INDEX idx_users_active ON users(community_id) WHERE deleted_at IS NULL;
