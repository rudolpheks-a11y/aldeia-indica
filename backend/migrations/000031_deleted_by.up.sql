-- Quem excluiu a conta decide se ela pode ser reativada pelo próprio dono.
-- Autoexclusão (deleted_by = o próprio id): o dono reativa sozinho, fazendo
-- login com a senha antiga.
-- Exclusão pelo admin (deleted_by = id do admin): o dono NÃO reativa — senão
-- banir um fraudador seria inútil, bastaria ele logar de novo.
ALTER TABLE users ADD COLUMN deleted_by UUID REFERENCES users(id);

-- O e-mail continua preso à conta excluída de propósito (não é anonimizado):
-- é o que impede um prestador de se recadastrar com o mesmo e-mail para fugir
-- de uma avaliação ruim. Recadastro com e-mail de conta excluída é bloqueado
-- pela UNIQUE(community_id, email) que já existe, e o usuário é instruído a
-- reativar a conta antiga.
COMMENT ON COLUMN users.deleted_at IS
  'Exclusão é reversível: os dados ficam intactos para preservar o histórico de avaliações (antifraude). Ver docs/database.md.';
