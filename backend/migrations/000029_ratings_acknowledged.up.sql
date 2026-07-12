-- Aceite do prestador sobre avaliações públicas: ao se cadastrar, o
-- prestador marca um checkbox reconhecendo que moradores poderão avaliar
-- seus serviços e que as avaliações ficam públicas no perfil.
-- Guardamos o TIMESTAMP do aceite (não um booleano): registra QUANDO cada
-- prestador tomou conhecimento. NULL = cadastro anterior à exigência
-- (decisão de produto 2026-07-12: o aceite vale só para novos cadastros;
-- os 12 prestadores existentes ficam NULL de propósito).
ALTER TABLE provider_profiles
    ADD COLUMN ratings_acknowledged_at TIMESTAMPTZ;
