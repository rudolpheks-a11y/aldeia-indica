-- Remove o rastreamento de "contratação confirmada" — nunca teve nenhum
-- botão real no app (nenhum morador tinha como disparar isso), e o
-- propósito do produto é facilitar achar prestadores e formar uma rede de
-- confiança por avaliação/indicação, não rastrear se um serviço foi
-- efetivamente contratado. O peso que TotalHires tinha na fórmula do Score
-- Aldeia foi redistribuído (ver internal/domain/score.go).
DROP TABLE provider_hires;
ALTER TABLE provider_profiles DROP COLUMN total_hires;
