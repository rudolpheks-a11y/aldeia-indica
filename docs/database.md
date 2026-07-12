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
| 000030 | `users.deleted_at` — exclusão de conta é soft-delete reversível (ver abaixo) |
| 000031 | `users.deleted_by` — quem excluiu decide quem pode reativar (antifraude) |
| 000018 | índices `provider_services(provider_id)` e `service_request_responses(request_id)` |
| 000019 | `provider_hires` |
| 000020 | remove aprovação de documentos do prestador |
| 000021 | remove `approval_votes` |
| 000022 | remove rastreamento de contratação (`provider_hires`, `total_hires`) |
| 000023 | `provider_availability`: troca `UNIQUE(provider_id, day_of_week)` por `UNIQUE(provider_id, day_of_week, start_time)` — permite múltiplos horários no mesmo dia |
| 000024 | remove `provider_photos` ("Trabalhos realizados" — nunca teve tela de upload) |
| 000025 | `notifications` (in-app: resposta a pedido, avaliação recebida, indicação recebida) |
| 000026 | `provider_questions` + `provider_question_answers` (perguntas públicas no perfil do prestador) |
| 000027 | `provider_favorites` (morador salva prestador para ver depois) |

## Regras do schema

- `users.status`: `pending` → `active` → `suspended`. Moradores precisam de aprovação para virar `active`.
- `provider_profiles.is_visible = false` até admin aprovar documentos (`doc_status = 'approved'`).
- `conversations`: `CHECK (participant_a < participant_b)` — par canônico, evita duplicatas.
- `ratings`: `UNIQUE(community_id, provider_id, rater_id)` — um morador avalia um prestador uma vez.
- `recommendations`: `UNIQUE(community_id, provider_id, recommender_id)` — idem.
- `provider_availability`: `UNIQUE(provider_id, day_of_week, start_time)` — permite múltiplos horários no mesmo dia, desde que não comecem no mesmo horário (migration 000023).

## Score Aldeia

Fórmula em `internal/domain/score.go`:

```
score = (avg_rating/5 × 35) + (min(anos/10, 1) × 15) +
        (min(clientes/50, 1) × 20) + (min(contratações/100, 1) × 15) +
        (min(indicações/20, 1) × 15)
```

Recalculado na mesma transação após: inserção de rating, inserção/remoção de recommendation, `POST /providers/:id/hire`. Persistido em `provider_profiles.score_aldeia`. Sem cron.

## Exclusão de conta (soft-delete reversível) — antifraude

`DELETE /users/me` e `DELETE /admin/users/:id` **não apagam nada e não anonimizam**:
marcam `deleted_at = now()` e `deleted_by = <quem excluiu>` (migrations 000030 e 000031),
e revogam os refresh tokens. E-mail, nome, senha e histórico permanecem intactos.

**Por que não anonimizar (decisão de produto, 2026-07-12):** o e-mail tem que continuar
preso à conta excluída. Se ele fosse liberado, um prestador poderia excluir a conta e se
recadastrar com o mesmo e-mail para nascer sem as avaliações ruins. Recadastro com
e-mail de conta excluída é bloqueado (**409 + `code: email_taken_deleted`**) e a pessoa é
instruída a reativar a conta antiga — que volta com o histórico junto.

**Por que também não apagar de verdade:** a maioria das FKs para `users(id)` é RESTRICT
(`ratings`, `recommendations`, `messages`, `service_requests`, `provider_questions`) — o
Postgres bloquearia o `DELETE`, e um `ON DELETE CASCADE` apagaria as avaliações e
indicações que a pessoa **deu a terceiros**, alterando o Score Aldeia de quem ficou.

**`deleted_by` decide quem pode reativar:**
- `deleted_by = o próprio id` (autoexclusão) → o dono reativa sozinho: o login devolve
  **403 + `code: account_deleted`**, o app oferece "Reativar conta" e chama
  `POST /auth/reactivate` (e-mail + senha antiga = prova de posse).
- `deleted_by = id de um admin` (banimento) → o dono **não** reativa: login e reactivate
  devolvem **403 + `code: account_deleted_by_admin`**. Sem essa distinção, banir um
  fraudador não valeria de nada — bastaria ele logar de novo.

**Visibilidade do admin:** `GET /admin/users?deleted=true` lista as contas excluídas com
`deleted_at` e `deleted_by_admin` — é a trilha antifraude (aba "Excluídos" no painel).

**Todo caminho de leitura filtra `deleted_at IS NULL`:** login, busca/featured de
prestadores, perfil por id, favoritos, `/admin/users` e `/admin/stats`. Ao adicionar uma
query nova sobre `users`, incluir o filtro.

**Admin não exclui admin** (nem a si mesmo) — 403. Remoção de moderador é operação de
banco, deliberadamente fora do app.

**Tensão conhecida (LGPD):** "excluir conta" aqui é desativação, não apagamento de dados
pessoais. A escolha foi deliberada e prioriza a integridade da rede de confiança. Se um
dia for preciso atender a um pedido formal de eliminação de dados, será um fluxo
separado (e provavelmente manual, no banco).
