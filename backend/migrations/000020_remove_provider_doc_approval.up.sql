-- Remove o gate de "aprovação de documentos" do prestador — nunca foi
-- implementado de verdade no mobile (nenhum upload real de CPF/RG existia),
-- então o admin aprovava cadastros só olhando nome/e-mail. Prestador passa a
-- nascer ativo/visível direto no cadastro (ver internal/service/auth.go).
--
-- Ativa automaticamente quem ficou preso no limbo (nunca revisado), mas NÃO
-- ressuscita quem foi explicitamente rejeitado por um admin (doc_status =
-- 'rejected') — essa distinção importa para não reativar contas suspensas
-- por má conduta ao rodar esta migration em produção.
UPDATE users u SET status = 'active'
  FROM provider_profiles pp
  WHERE u.id = pp.user_id AND u.role = 'prestador' AND u.status = 'pending'
    AND pp.doc_status != 'rejected';

UPDATE provider_profiles SET is_visible = true
  WHERE is_visible = false AND doc_status != 'rejected';

ALTER TABLE provider_profiles DROP COLUMN doc_status;
ALTER TABLE provider_profiles DROP COLUMN doc_cpf_key;
ALTER TABLE provider_profiles DROP COLUMN doc_id_key;
DROP TYPE doc_status;

ALTER TABLE provider_profiles ALTER COLUMN is_visible SET DEFAULT true;
