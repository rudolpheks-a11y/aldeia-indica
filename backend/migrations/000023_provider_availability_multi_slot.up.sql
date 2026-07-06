-- Permite que o prestador cadastre mais de um horário de disponibilidade no
-- mesmo dia da semana (ex.: 08:00-12:00 e 14:00-18:00 na mesma segunda).
-- A UNIQUE (provider_id, day_of_week) impedia mais de uma linha por dia;
-- troca para impedir apenas duplicatas exatas do mesmo horário.
ALTER TABLE provider_availability DROP CONSTRAINT provider_availability_provider_id_day_of_week_key;
ALTER TABLE provider_availability ADD CONSTRAINT provider_availability_provider_id_day_of_week_start_time_key
    UNIQUE (provider_id, day_of_week, start_time);
