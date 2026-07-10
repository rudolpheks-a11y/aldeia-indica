-- Requisito de segurança: o prestador só pode saber a QUANTIDADE de visitas
-- ao perfil, nunca QUEM visitou. A partir de agora o handler grava
-- profile_view com actor_id = NULL (ver internal/handler/provider.go), mas as
-- visitas registradas ANTES desta mudança ainda carregam a identidade do
-- visitante — esta migration apaga esses vínculos retroativamente.
--
-- Só afeta profile_view. contact_initiated mantém actor_id: quando um morador
-- inicia contato, ele deliberadamente se revela ao prestador (abre um chat
-- identificado), então guardar quem contatou é consistente com o produto.
UPDATE provider_events SET actor_id = NULL WHERE event_type = 'profile_view';
