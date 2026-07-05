-- Aprovação de morador deixa de ser "pending + votos depois" e passa a ser
-- resolvida na hora do cadastro via 2 códigos de convite (tabela `invites`,
-- já existente, agora consumida durante o registro em vez de pós-login).
-- Nenhum usuário nasce mais 'pending' (nem morador, nem prestador — ver
-- migration 000020), então este mecanismo fica 100% morto.
DROP TABLE approval_votes;
DROP TABLE user_approvals;
DROP TYPE approval_status;
DROP TYPE approval_method;
