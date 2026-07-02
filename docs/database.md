# Database

## Migrations

Numeradas sequencialmente em `backend/migrations/`. Rodar via `make migrate-up`.

| Migration | Conteúdo |
|---|---|
| 000001 | `communities` |
| 000002 | `users`, `morador_profiles`, `refresh_tokens`, `device_tokens` |
| 000003 | `user_approvals`, `approval_votes`, `invites` |
| 000004 | `provider_profiles`, `provider_photos` |
| 000005 | `service_categories`, `provider_services` |
| 000006 | `ratings` |
| 000007 | `recommendations` |
| 000008 | `conversations`, `messages` |
| 000009 | `service_requests`, `service_request_responses` |
| 000010 | `provider_events` |
| 000011 | seed das 17 categorias de serviço |
| 000012 | índices de analytics e ranking por categoria |
| 000013 | `password_reset_tokens` (código 6 dígitos, expira em 15 min) |
| 000014 | `provider_profiles`: colunas `needs_transport`, `transport_type` |
| 000015 | `provider_availability` (day_of_week 0-6, start_time/end_time "HH:MM") |
| 000016 | `messages`: colunas `media_key`, `lat`, `lng` |
| 000017 | `bulletin_posts` (mural de avisos, com aprovação admin) |
| 000018 | índices `provider_services(provider_id)` e `service_request_responses(request_id)` |

## Regras do schema

- `users.status`: `pending` → `active` → `suspended`. Moradores precisam de aprovação para virar `active`.
- `provider_profiles.is_visible = false` até admin aprovar documentos (`doc_status = 'approved'`).
- `conversations`: `CHECK (participant_a < participant_b)` — par canônico, evita duplicatas.
- `ratings`: `UNIQUE(community_id, provider_id, rater_id)` — um morador avalia um prestador uma vez.
- `recommendations`: `UNIQUE(community_id, provider_id, recommender_id)` — idem.
- `provider_availability`: `UNIQUE(provider_id, day_of_week)` — um slot por dia.

## Score Aldeia

Fórmula em `internal/domain/score.go`:

```
score = (avg_rating/5 × 35) + (min(anos/10, 1) × 15) +
        (min(clientes/50, 1) × 20) + (min(contratações/100, 1) × 15) +
        (min(indicações/20, 1) × 15)
```

Recalculado na mesma transação após: inserção de rating, inserção/remoção de recommendation, `POST /providers/:id/hire`. Persistido em `provider_profiles.score_aldeia`. Sem cron.
