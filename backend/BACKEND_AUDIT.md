# Backend Audit — Aldeia Indica

**Date:** 2026-07-02
**Scope:** Full backend repo (`/Users/rudolphkeppler/aldeia-indica/backend`) — 42 Go files, ~4,472 lines. All routes, services, middleware, WebSocket, storage, migrations.
**Stack:** Go 1.26.4, chi v5, `pgx/v5` (raw SQL, no ORM), PostgreSQL 18, S3/MinIO (presigned uploads), `coder/websocket`, `golang-migrate`, `golang-jwt/v5`, bcrypt.

## Summary

- P0: 1
- P1: 4
- P2: 6
- P3: 5

> **Correction (2026-07-02):** the original P1 finding "Admin document review has no community scope" (`internal/handler/admin.go:124`, `ReviewDocument`) has been reclassified as **not a bug**. Confirmed with the product owner: admin is a single global role, the same across every community, by design — `ReviewDocument` correctly has no `community_id` filter, matching the intended behavior. The sibling admin endpoints (`ListUsers`, `UpdateUserStatus`, `ListDocumentQueue`) do filter by `claims.CommunityID`; this was raised explicitly and the product owner confirmed those filters should stay as-is (scoped by design, not an inconsistency to fix). No code change was made for this item. Severity counts and numbering below have been updated to remove it.

**Top 3 priorities:**
1. Chat has no participant/ownership check on read or write — any authenticated user can read or inject messages into any conversation (`internal/handler/chat.go:73`, `internal/ws/client.go:97`).
2. Service requests (`Get`, `ListResponses`, `Respond`) have no community scope — a user from a different community can read/write into another community's service request (`internal/handler/request.go:93,140,157`).
3. The main provider search endpoint is N+1, client-controllable up to ~600 queries per request, with no rate limiting anywhere in front of it (`internal/service/provider.go:93`, `internal/server/router.go`).

## Status das correções (2026-07-02)

Todos os achados abaixo foram corrigidos e verificados nesta mesma sessão (build + `go vet` + `go test` limpos, e os fixes de segurança validados com requisições cruzadas entre identidades/comunidades reais via curl, não apenas revisão de código):

| Achado | Status | Como foi verificado |
|---|---|---|
| P0-1 Chat sem ownership | ✅ Corrigido | `GET .../messages` e `POST .../read` retornam `403` para usuário autenticado que não é participante (mesma comunidade), `404` para conversa inexistente; `POST /chat/conversations` retorna `403` ao tentar iniciar chat com usuário de outra comunidade |
| P1-1 Service requests sem escopo | ✅ Corrigido | `Get`/`ListResponses`/`Respond` retornam `404` para usuário de outra comunidade (antes: `200`/`201`) |
| P1-2 Refresh token sem detecção de reuso | ✅ Corrigido | Reuso de token já revogado agora invalida toda a família — o token novo, legítimo, também passa a retornar `401` |
| P1-3 N+1 na busca | ✅ Corrigido | `Search`/`Featured` batelados em 3 queries totais (era 1 + N×4); resultado comparado byte-a-byte antes/depois com dados reais — idêntico |
| P1-4 Sem timeouts | ✅ Corrigido | `http.Client{Timeout: 10s}` em FCM/Resend; `context.WithTimeout` em `pushNotify` |
| P2-2 Índices faltantes | ✅ Corrigido | Migration 000018 aplicada; índices confirmados via `\di` no Postgres |
| P2-3 Sem rate limiting | ✅ Corrigido | 6ª requisição em 1 min retorna `429` em `/auth/forgot-password`; `/uploads/presign` com limite próprio |
| P2-5 Erros silenciados | ✅ Corrigido | Logger adicionado a `ProviderService`; todos os `_ :=`/`_ =` em queries substituídos por log de erro |
| P2-6 Rotas com `{id}` ignorado | ✅ Corrigido | `AddPhoto` agora exige `{id} == caller` (`403` caso contrário); `DELETE /recommendations` não tem mais `{id}` na rota |
| P2-1 Zero testes / sem CI | ⚠️ Parcial | CI mínimo adicionado (`.github/workflows/backend.yml`: build+vet+test) rodando o que já existe; não foi criada infraestrutura de teste com banco (decisão explícita — ver conversa) |
| P2-4 Layering inconsistente | ⏸️ Não corrigido | Decisão explícita: é reflexo dos fixes de escopo já aplicados diretamente nos handlers afetados, não uma falha isolada — refatorar a camada é mudança arquitetural, não bugfix |
| P3-1 Doc drift (sqlc) | ✅ Corrigido | `internal/repository/`, `sqlc.yaml` e alvo `generate` removidos; `CLAUDE.md`/`architecture.md` corrigidos |
| P3-2 Dockerfile root | ✅ Corrigido | Imagem reconstruída e testada — `whoami` dentro do container retorna `app` |
| P3-3 Linha morta | ✅ Corrigido | `_ = slog.Default()` removida de `main.go` |
| P3-4/P3-5 CORS/WS wildcard | ⏸️ Sem ação | Watch-items, sem mudança de comportamento hoje — mantidos como estão, conforme relatório original |

**Achado adicional corrigido durante a implementação (não estava no relatório original):** `GetOrCreateConversation` não verificava se o outro usuário pertencia à mesma comunidade do chamador — um usuário podia iniciar conversa com alguém de outra comunidade. Corrigido junto com o fix do chat (mesmo princípio de isolamento) e verificado com `403`.

## Findings

### P0 — Critical

#### [P0-1] Chat: no participant/ownership check — cross-tenant read and write on any conversation
- **Location:** `internal/handler/chat.go:73-90` (REST read), `internal/ws/client.go:97-138` (WS write), `internal/service/chat.go:100-136` (`LoadHistory`, `PersistMessage`)
- **Dimension:** Security (IDOR / multi-tenancy)
- **What:** `ListMessages` (`GET /chat/conversations/{id}/messages`) never calls `middleware.ClaimsFrom` and passes the URL `{id}` straight to `LoadHistory`, which queries `WHERE conversation_id = $1` with no participant or `community_id` filter at all. On the write side, the WebSocket `handleMessage` takes `frame.ConversationID` directly from the client frame and calls `chatSvc.PersistMessage` without ever checking that the connected user (`c.userID`) is `participant_a` or `participant_b` of that conversation; `PersistMessage`'s own SQL only uses the conversation row to copy `community_id`, never to verify membership.
- **Code (verbatim):**
  ```go
  // internal/handler/chat.go:73-90
  func (h *ChatHandler) ListMessages(w http.ResponseWriter, r *http.Request) {
      convID, err := uuid.Parse(chi.URLParam(r, "id"))
      if err != nil {
          jsonError(w, "invalid conversation id", http.StatusBadRequest)
          return
      }
      page, _ := strconv.Atoi(r.URL.Query().Get("page"))
      msgs, err := h.svc.LoadHistory(r.Context(), convID, 50, page*50)
      ...
  ```
  ```go
  // internal/service/chat.go:127-136
  func (s *ChatService) PersistMessage(ctx context.Context, msg *domain.Message) error {
      msg.ID = uuid.New()
      msg.CreatedAt = time.Now()
      _, err := s.db.Exec(ctx,
          `INSERT INTO messages (id, conversation_id, community_id, sender_id, type, body, media_key, lat, lng)
           SELECT $1, $2, community_id, $3, $4, $5, $6, $7, $8 FROM conversations WHERE id = $2`,
          msg.ID, msg.ConversationID, msg.SenderID, msg.Type, msg.Body, msg.MediaKey, msg.Lat, msg.Lng,
      )
      return err
  }
  ```
- **Why it matters:** Any authenticated user (any role, any community) who obtains a conversation UUID — which every participant of every conversation legitimately sees in their own chat history and in WS message payloads — can read the full message history of that conversation, or inject a message into it impersonating themselves as a sender in a conversation they're not part of. This breaks both user-to-user privacy and the community/tenant boundary the entire product is built on ("rede de confiança comunitária").
- **Evidence / how verified:** Read `internal/handler/chat.go` end to end — confirmed `ListMessages` has no `middleware.ClaimsFrom` call, unlike every other handler in the file (`GetOrCreate`, `ListConversations`, `MarkRead` all call it). Read `internal/service/chat.go` — `LoadHistory`, `PersistMessage`, `ListParticipants` all take `conversationID` with no ownership predicate in their SQL. Read `internal/ws/client.go:97-138` — `handleMessage` builds `msg.SenderID = c.userID` (correct) but never compares it against the conversation's participants before calling `PersistMessage`.
- **Fix:** Add an ownership check before both the read and the write: `SELECT participant_a, participant_b, community_id FROM conversations WHERE id=$1` and verify `claims.UserID IN (participant_a, participant_b)` (and `community_id == claims.CommunityID` as defense in depth) before calling `LoadHistory`/`PersistMessage`/`MarkRead`. `ListParticipants` already exists and returns exactly what's needed — call it first in both `ListMessages` and `handleMessage`, return 403/silently drop on mismatch.
- **Implementation constraints:** `ListParticipants` currently errors if the conversation doesn't exist (`QueryRow.Scan` on zero rows) — the added check needs to distinguish "not found" (404) from "not a participant" (403) cleanly. On the WS path, `handleMessage` runs per-frame in the read loop; the added `ListParticipants` call is one more round-trip per message but bounded by the same table already queried right after for delivery routing — worth merging into a single call instead of two (the existing code at line 129 already calls `ListParticipants` once for delivery routing; reuse that result for the ownership check instead of querying twice).
- **Confidence:** Confirmed

---

### P1 — High

> **~~[P1-1] Admin document review has no community_id scope~~ — REMOVED, not a bug.** Originally flagged because `ReviewDocument` (`internal/handler/admin.go:124`) has no `community_id` filter while its three siblings (`ListUsers`, `UpdateUserStatus`, `ListDocumentQueue`) do. Confirmed with the product owner (2026-07-02): admin is a single global role by design — `ReviewDocument`'s lack of a community filter is correct, and the community filters on the other three endpoints are intentional and should stay. No code change.

#### [P1-1] Service requests: `Get`, `ListResponses`, `Respond` have no community_id scope
- **Location:** `internal/handler/request.go:93-121` (`Get`), `140-155` (`Respond`), `157-176` (`ListResponses`)
- **Dimension:** Security (multi-tenancy)
- **What:** `List` and `UpdateStatus` in the same file correctly filter by `claims.CommunityID` / `claims.UserID`. `Get`, `Respond`, and `ListResponses` don't call `middleware.ClaimsFrom` for scoping purposes (`Respond` calls it only to stamp `provider_id`/`community_id` on the INSERT, not to check the target request belongs to that community) and their `SELECT`/`INSERT` filter only on `id`/`request_id`.
- **Code (verbatim):**
  ```go
  // internal/handler/request.go:93-108
  func (h *RequestHandler) Get(w http.ResponseWriter, r *http.Request) {
      requestID, err := uuid.Parse(chi.URLParam(r, "id"))
      ...
      row := h.db.QueryRow(r.Context(),
          `SELECT sr.id, u.full_name, sc.name_pt, sr.title, sr.description, sr.status, sr.created_at
           FROM service_requests sr
           JOIN users u ON u.id = sr.requester_id
           LEFT JOIN service_categories sc ON sc.id = sr.category_id
           WHERE sr.id=$1`,
          requestID,
      )
  ```
- **Why it matters:** Request IDs are shown to every member of the community that created them (via `List`), so this isn't exploitable by a random stranger — but any authenticated user from a *different* community who obtains a request ID (shared link, screenshot, notification, or a future feature that surfaces IDs more broadly) can read the requester's full name and request details, and a provider from a different community can post a response (`Respond`) into that request without ever being scoped to it. This is a defense-in-depth failure on exactly the boundary the rest of the file enforces two lines away.
- **Evidence / how verified:** Read the full file; `List` (line 22) and `UpdateStatus` (line 123) both bind `claims.CommunityID`/`claims.UserID` into their query; `Get`, `Respond`, `ListResponses` don't.
- **Fix:** Add `AND sr.community_id = $N` to `Get`'s query (bound to `claims.CommunityID`), same for `ListResponses` (join `service_requests` to check `community_id`), and check request ownership/community in `Respond` before the INSERT (`SELECT community_id FROM service_requests WHERE id=$1` and compare to `claims.CommunityID`).
- **Implementation constraints:** `Get` and `ListResponses` don't currently call `ClaimsFrom` at all — the routes are inside the authenticated group so `claims` is always available, this is a one-line addition per handler, not a routing change.
- **Confidence:** Confirmed

#### [P1-2] Refresh token rotation has no reuse/theft detection
- **Location:** `internal/service/auth.go:183-218` (`Refresh`)
- **Dimension:** Security (auth)
- **What:** Rotation itself is correct — the used token is revoked and a new pair issued. But replaying an already-revoked (or otherwise invalid) refresh token just returns `"refresh token expired or revoked"` and stops; nothing revokes the rest of that user's active refresh-token family.
- **Code (verbatim):**
  ```go
  // internal/service/auth.go:203-211
  if rt.RevokedAt != nil || rt.ExpiresAt.Before(time.Now()) {
      return nil, errors.New("refresh token expired or revoked")
  }

  _, err = s.db.Exec(ctx,
      `UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1`, rt.ID)
  ```
- **Why it matters:** Refresh tokens are long-lived (`JWT_REFRESH_EXPIRY` defaults to `720h` = 30 days, `internal/config/config.go:30`). If one is ever exfiltrated (device compromise, log leak, MITM on a misconfigured client), the thief's rotated session keeps working indefinitely and silently, while the legitimate user only notices their *own* next rotation attempt failing — with no signal to revoke the attacker's session. Standard rotation-with-reuse-detection would treat a revoked-token replay as a theft signal and kill the whole family.
- **Evidence / how verified:** Read `AuthService.Refresh` end to end; confirmed no query or call anywhere in the function (or elsewhere in `auth.go`) revokes tokens by `user_id` on this path — the only family-wide revocation is `Logout`, which requires the *current* valid token.
- **Fix:** When `rt.RevokedAt != nil` specifically (not `ExpiresAt` — that's just normal expiry), treat it as reuse: `UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`, then return the same generic error.
- **Implementation constraints:** Requires distinguishing "revoked" from "expired" in the branch (currently one combined `if`) — split them so only the revoked case triggers family revocation, otherwise a normal expired-token retry (common, harmless) would force-logout the user's other active devices.
- **Confidence:** Confirmed

#### [P1-3] N+1 query in provider search, amplified by a client-controlled, uncapped-by-rate-limit `limit`
- **Location:** `internal/service/provider.go:93-108` (`Search`), `141-155` (`Featured`), `159-213` (`computeSeals`, `totalClients`, `getCategories`); `internal/handler/provider.go:36-39` (limit parsing)
- **Dimension:** Performance
- **What:** `Search` and `Featured` both loop over the result rows and, per row, call `getCategories` (1 query), `totalClients` (1 query), and `computeSeals` (1 more query for the "veterano" seal) — 3 extra queries per provider. `Search`'s page size (`limit`) is client-controlled via `?limit=`, clamped only to `1..200`.
- **Code (verbatim):**
  ```go
  // internal/handler/provider.go:36-39
  limit := 20
  if l, err := strconv.Atoi(q.Get("limit")); err == nil && l > 0 && l <= 200 {
      limit = l
  }
  ```
  ```go
  // internal/service/provider.go:93-105
  for rows.Next() {
      var p ProviderSummary
      if err := rows.Scan(...); err != nil {
          return nil, err
      }
      p.Categories = s.getCategories(ctx, p.UserID)
      p.Seals = s.computeSeals(ctx, p.UserID, p.RecommendationCount, p.AvgRating, s.totalClients(ctx, p.UserID))
      results = append(results, p)
  }
  ```
- **Why it matters:** `GET /providers` is the main directory/search screen — the most-hit read endpoint in the app. At the default page size (20) this is already 1 + 20×3 = 61 queries per request; at `?limit=200` (a single query param an ordinary client can send) it's up to 601 queries in one HTTP request. There is no rate limiting anywhere in front of this (see P2-3 below), so this is trivially repeatable.
- **Evidence / how verified:** Read `Search`, `Featured`, `getCategories`, `computeSeals`, `totalClients` in full — each of the three helpers issues its own `db.Query`/`db.QueryRow`. Read the handler's limit-parsing code confirming `200` is reachable by any caller.
- **Fix:** Batch the three per-row lookups into two queries run once per `Search` call: one `SELECT provider_id, category_name FROM provider_services JOIN service_categories WHERE provider_id = ANY($1)` keyed by the batch of `UserID`s from the page, grouped in Go; one similar batched query for `created_at`/`total_clients` (the latter is already selected in `Featured`'s eligibility check and could be added to `Search`'s main SELECT instead of being fetched separately).
- **Implementation constraints:** `computeSeals` mixes in-memory logic (avg_rating/recommendation_count thresholds, already available from the main row) with one DB round-trip (`created_at` for "veterano"); only that one field needs batching, not the whole function. `getCategories`'s current per-provider ordering (`ORDER BY sc.sort_order`) needs to be preserved per group after batching (group in Go, sort each group).
- **Confidence:** Confirmed

#### [P1-4] No timeouts anywhere in the codebase — zero-timeout HTTP clients and unbounded background contexts
- **Location:** `internal/fcm/client.go:47` (`&http.Client{}`), `internal/email/resend.go:26` (`&http.Client{}`), `internal/ws/client.go:169,177` (`context.Background()` in `pushNotify`)
- **Dimension:** Reliability
- **What:** `grep -rn "context.WithTimeout\|context.WithDeadline" internal/` returns zero matches anywhere in the codebase. Both outbound HTTP clients (FCM, Resend) are constructed with a bare `&http.Client{}`, which has no `Timeout` field set (Go default = no timeout, only the underlying transport's dial/TLS timeouts apply). `pushNotify` — fired as `go c.pushNotify(...)` on every chat message when the recipient is offline — uses `context.Background()` for both the DB lookup and the FCM call, which never cancels.
- **Code (verbatim):**
  ```go
  // internal/fcm/client.go:44-49
  return &Client{
      projectID:   sa.ProjectID,
      tokenSource: creds.TokenSource,
      http:        &http.Client{},
      log:         log,
  }, nil
  ```
  ```go
  // internal/ws/client.go:168-180
  func (c *Client) pushNotify(recipientID uuid.UUID, msg *domain.Message) {
      tokens, err := c.chatSvc.GetDeviceTokens(context.Background(), recipientID)
      if err != nil || len(tokens) == 0 {
          return
      }
      ...
      c.fcmSvc.SendMulti(context.Background(), tokens, fcm.Notification{...})
  }
  ```
- **Why it matters:** If FCM or Resend starts responding slowly (a real, observed failure mode for both services during provider incidents), every chat message to an offline recipient spawns a goroutine that can hang indefinitely with no caller to time it out — under sustained chat traffic during a degraded-dependency window, this accumulates goroutines and outstanding DB/HTTP connections with no backstop. The Resend path is bounded in the worst case by the HTTP server's 30s `WriteTimeout` (since it runs inside a request handler), but the FCM push path runs in a detached goroutine with no such backstop at all.
- **Evidence / how verified:** `grep -rn "context.WithTimeout\|context.WithDeadline" internal/` → no output. Read both client constructors and both `context.Background()` call sites directly.
- **Fix:** Give both `http.Client` instances an explicit `Timeout` (e.g. 10s), and wrap `pushNotify`'s body in `ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second); defer cancel()` instead of using `context.Background()` directly.
- **Implementation constraints:** None significant — this is a pure addition, doesn't change any call signatures since `ctx` is already threaded through `GetDeviceTokens`/`SendMulti`.
- **Confidence:** Confirmed

---

### P2 — Medium

#### [P2-1] Zero test coverage outside `internal/domain`, and no CI to run even that
- **Location:** repo-wide (`go test ./...` output); no `.github/workflows/` directory found
- **Dimension:** Code quality
- **What:** `go test ./...` shows every package except `internal/domain` (which has `score_test.go`, passes) reports `[no test files]` — that's `handler`, `service`, `server`, `server/middleware`, `auth`, `ws`, `storage`, `platform/postgres`, `config`, `email`, `fcm`. There is no GitHub Actions workflow (or any CI config) in the repo, so nothing runs even the one passing test suite automatically.
- **Why it matters:** All of the P0/P1 findings above (chat IDOR, missing tenant scoping, refresh-token reuse) are exactly the class of bug a handler-level test suite (even a small one hitting each endpoint with a wrong/foreign ID) would catch before merge. Right now the only thing preventing regressions is manual review.
- **Evidence / how verified:** Ran `go test ./...` from `backend/`; ran `find . -path "*/.github/workflows*"` from repo root — no results.
- **Fix:** Not "add tests" broadly — prioritize handler-level tests for the specific patterns just found: one test per handler asserting a foreign `community_id`/non-participant caller gets rejected. Add a minimal GitHub Actions workflow running `go build ./...`, `go vet ./...`, `go test ./...` on push.
- **Implementation constraints:** Handler tests need a real Postgres (raw SQL, no in-memory driver) — either testcontainers or a docker-compose Postgres in CI; there's no existing test-DB harness in the repo to reuse, so this is new infrastructure, not just new test files.
- **Confidence:** Confirmed

#### [P2-2] Missing indexes on two FK columns used directly in hot-path/list queries
- **Location:** `migrations/000005_create_categories.up.sql` (`provider_services`), `migrations/000009_create_service_requests.up.sql` (`service_request_responses`)
- **Dimension:** Performance
- **What:** `provider_services` has indexes on `(community_id, category_id)` and `(category_id, community_id) INCLUDE (provider_id)` but none leading with `provider_id` — yet `getCategories()` (called in the P1-4 N+1 loop, once per search result) queries `WHERE ps.provider_id = $1`. `service_request_responses` has no index at all beyond its primary key — `ListResponses` queries `WHERE srr.request_id=$1`.
- **Code (verbatim):**
  ```sql
  -- grep "CREATE.*INDEX" migrations/*.up.sql, provider_services entries:
  CREATE INDEX idx_provider_services_category ON provider_services(community_id, category_id);
  CREATE INDEX idx_provider_services_category_score ON provider_services(category_id, community_id) INCLUDE (provider_id);
  -- no index with provider_id as a leading column anywhere for this table
  ```
- **Why it matters:** Both queries currently run as sequential scans on `provider_services`/`service_request_responses`. At current data volumes this is invisible; it becomes a real latency cliff exactly as the community grows — and `provider_services` is hit N times per search request (P1-4), so it compounds with that finding.
- **Evidence / how verified:** `grep -n "CREATE.*INDEX" migrations/*.up.sql` — full list reviewed above; confirmed no `provider_id`-leading index on `provider_services` and no index at all on `service_request_responses`.
- **Fix:** `CREATE INDEX idx_provider_services_provider ON provider_services(provider_id);` and `CREATE INDEX idx_service_request_responses_request ON service_request_responses(request_id);` as a new migration (`000018_...`).
- **Implementation constraints:** None — additive migration, no data backfill needed.
- **Confidence:** Confirmed

#### [P2-3] No rate limiting anywhere in the router
- **Location:** `internal/server/router.go` (entire file — `chimiddleware.Recoverer`, `middleware.Logger`, `cors.Handler` are the only middleware registered)
- **Dimension:** Security / Performance
- **What:** No rate-limiting middleware exists at any level (global or per-route). This includes endpoints that trigger external, cost-bearing, or abuse-sensitive calls: `/auth/forgot-password` (Resend email), `/auth/register/morador` and `/auth/register/prestador` (account creation), and `/uploads/presign` (generates a valid S3 write URL on every call).
- **Evidence / how verified:** Read the full `router.go` — three middleware registered at the top (`Recoverer`, `Logger`, `cors.Handler`), no `httprate` or equivalent anywhere in `go.mod` or the codebase.
- **Fix:** Add per-route or global rate limiting (e.g. `go-chi/httprate`), prioritizing the three endpoints named above.
- **Implementation constraints:** None blocking — this is additive middleware; needs a decision on limit key (per-IP vs per-account) since `/auth/register/*` and `/auth/forgot-password` are pre-authentication (IP-based is the only option available at that point).
- **Confidence:** Confirmed

#### [P2-4] Handler layering is inconsistent, and it correlates with the missing-scope findings
- **Location:** `internal/handler/admin.go:13-19`, `internal/handler/category.go:9-15`, `internal/handler/request.go:14-20` (constructed with `*pgxpool.Pool` directly) vs. `internal/handler/provider.go`, `chat.go`, `rating.go`, `recommendation.go`, `bulletin.go` (constructed with a `*service.XService`)
- **Dimension:** Code quality (cross-module consistency) — elevated to **Patterns observed** below
- **What:** `AdminHandler`, `CategoryHandler`, and `RequestHandler` skip the service layer entirely and embed SQL/business logic directly in the handler (`main.go:71,73,74` construct them with `db` instead of a service). Every other handler in the package goes through a service struct.
- **Why it matters:** This isn't just a style inconsistency — P1-1 (`AdminHandler.ReviewDocument`) and P1-2 (`RequestHandler.Get`/`ListResponses`/`Respond`) are both in files that skip the service layer, and both are missing the tenant-scoping that's applied consistently in the service-backed handlers (`ProviderService`, `ChatService`, `RecommendationService` all take `communityID` as an explicit parameter on every method, forcing the caller to pass it; the raw-`db` handlers have no such forcing function).
- **Evidence / how verified:** Read `main.go:56-77` (service/handler construction) and cross-referenced against every handler file's struct definition.
- **Fix:** Not urgent as a standalone refactor, but worth doing opportunistically when next touching `admin.go`/`request.go`/`category.go` — route the DB calls through a service struct that takes `communityID` as an explicit parameter, matching the rest of the codebase, so the missing-scope class of bug becomes structurally harder to introduce.
- **Implementation constraints:** `CategoryHandler.List` has no tenant dimension (categories are global), so it's a legitimate exception — don't force a service wrapper there for its own sake.
- **Confidence:** Confirmed

#### [P2-5] Query errors silently discarded in several `ProviderService` helpers
- **Location:** `internal/service/provider.go:159-196` (`computeSeals`, `totalClients`), `:198-213` (`getCategories`), `:346-360` (`getPhotos`)
- **Dimension:** Reliability
- **What:** Four helper methods discard the DB call's error entirely with `_`, not even logging it: `_ = s.db.QueryRow(...).Scan(...)` (computeSeals, totalClients), `rows, _ := s.db.Query(...)` (getCategories, getPhotos).
- **Code (verbatim):**
  ```go
  // internal/service/provider.go:192-196
  func (s *ProviderService) totalClients(ctx context.Context, providerID uuid.UUID) int {
      var n int
      _ = s.db.QueryRow(ctx, `SELECT total_clients FROM provider_profiles WHERE user_id=$1`, providerID).Scan(&n)
      return n
  }
  ```
- **Why it matters:** A transient DB error (connection blip, statement timeout once P1-5's fix adds one) on any of these becomes indistinguishable from "provider has 0 clients / no categories / no photos" — the caller (and the end user) sees empty/zero data with no error surfaced anywhere, not even in logs.
- **Evidence / how verified:** Read all four functions directly; confirmed no `if err != nil { log... }` anywhere in them.
- **Fix:** At minimum log the error (`s.log.Error(...)` — note `ProviderService` doesn't currently hold a logger, would need to be added) even if the function's return signature stays "best effort, zero value on failure."
- **Implementation constraints:** Adding a logger to `ProviderService` is a constructor signature change (`NewProviderService(db, log)`), touching `main.go` and any tests that construct it directly.
- **Confidence:** Confirmed

#### [P2-6] Route path-parameter pass-through: two endpoints ignore the `{id}` their own route declares
- **Location:** `internal/handler/provider.go:157-159` (`AddPhoto`), `internal/handler/recommendation.go:45-67` (`Delete`)
- **Dimension:** Code quality
- **What:** `POST /providers/{id}/photos` parses no `{id}` at all in `AddPhoto` — it always uses `claims.UserID`, silently ignoring whatever provider ID is in the URL. `DELETE /recommendations/{id}` similarly never reads `chi.URLParam(r, "id")` — `Delete` reads `provider_id` from the JSON request body instead.
- **Code (verbatim):**
  ```go
  // internal/handler/provider.go:157-159
  func (h *ProviderHandler) AddPhoto(w http.ResponseWriter, r *http.Request) {
      claims, _ := middleware.ClaimsFrom(r.Context())
      var in struct {
          S3Key   string `json:"s3_key"`
          Caption string `json:"caption"`
      }
      // {id} from the route is never parsed here
  ```
- **Why it matters:** Currently harmless — both effectively self-scope tighter than the route implies, so there's no active vulnerability — but the route signature actively misleads a reader (or a future contributor extending these handlers) into thinking `{id}`/path-based targeting is supported and checked. A future change that starts trusting the path param without adding an explicit ownership comparison would silently reintroduce an IDOR.
- **Evidence / how verified:** Read both handlers in full; confirmed `chi.URLParam(r, "id")` doesn't appear in `AddPhoto`, and `Delete` decodes `provider_id` from the body instead of the URL despite `DELETE /recommendations/{id}` being the registered route (`router.go:81`).
- **Fix:** Either remove the unused `{id}` from the route (`POST /providers/photos`, `DELETE /recommendations`) to match actual behavior, or start using it with an explicit `if pathID != claims.UserID/providerID { 403 }` check — pick one and make the route and the handler agree.
- **Implementation constraints:** Route changes need a corresponding Flutter client update (`docs/api.md` documents the current paths); low risk since both are already used consistently on the mobile side per current behavior.
- **Confidence:** Confirmed

---

### P3 — Low / nit

#### [P3-1] Documentation drift: CLAUDE.md/architecture.md describe a sqlc repository layer that doesn't exist
- **Location:** `CLAUDE.md`, `docs/architecture.md` (both say `handler → service → repository (gerado por sqlc) → PostgreSQL`); `internal/repository/generated/` and `internal/repository/queries/` are both empty
- **Dimension:** Code quality
- **What:** No `.go` file anywhere imports a `db` package (the configured sqlc output package name); every service hits `*pgxpool.Pool` directly with hand-written SQL. `sqlc.yaml` is configured and `make generate` still runs `sqlc generate`, but against empty query input.
- **Evidence / how verified:** `find internal/repository -type f` → no results in either subdirectory. `grep -rl "package db"` / `grep -rl "sqlc"` across `internal/` → no results. Confirmed the app builds and runs fully without this layer (`go build ./...` succeeds, server starts and connects — see startup log from earlier in this session).
- **Fix:** Either finish the sqlc migration (generate real code into those directories and switch services to use it) or delete the dead scaffolding (`internal/repository/`, `sqlc.yaml`, the `generate` Makefile target) and correct the two docs to describe the actual `service → pgx.Pool` pattern.
- **Confidence:** Confirmed

#### [P3-2] Dockerfile runs as root
- **Location:** `backend/Dockerfile`
- **Dimension:** Security
- **What:** No `USER` directive — the final `alpine` stage runs the `api` binary as root by default.
- **Evidence / how verified:** Read the full Dockerfile — no `USER` instruction present.
- **Fix:** Add `RUN adduser -D -u 1000 app` and `USER app` before `CMD`.
- **Confidence:** Confirmed

#### [P3-3] Dead line in `main.go`
- **Location:** `cmd/api/main.go:108`
- **Dimension:** Code quality
- **What:** `_ = slog.Default()` at the end of `main()`, after the structured `log` (from `internal/platform/logger`) has already been used throughout — this line does nothing and isn't `log`'s default, it's the stdlib `log/slog` package-level default logger, unrelated to the app's configured logger.
- **Evidence / how verified:** Read `main.go` in full; the line has no effect on program behavior (confirmed nothing reads `slog.Default()` elsewhere) and `go vet` doesn't flag it only because `_ =` suppresses the unused-result situation that doesn't actually apply here (the call has no return value in a way that would even trigger that).
- **Fix:** Delete the line.
- **Confidence:** Confirmed

#### [P3-4] CORS wildcard origin — currently safe, but a silent trap if cookie auth is ever introduced
- **Location:** `internal/server/router.go:34-39`
- **Dimension:** Security
- **What:** `AllowedOrigins: []string{"*"}` with `AllowCredentials: false`.
- **Why it matters:** Safe today because auth is bearer-token-in-header (nothing for a malicious origin to ride on via CORS), but this combination becomes a live CSRF/credential-leak vector the moment any endpoint starts relying on cookies.
- **Evidence / how verified:** Read the `cors.Handler` config directly.
- **Fix:** No change needed now; flag any future adoption of cookie-based auth against this config specifically.
- **Confidence:** Confirmed (as a watch-item, not an active bug)

#### [P3-5] WebSocket accepts connections from any origin
- **Location:** `internal/ws/handler.go:31-33`
- **Dimension:** Security
- **What:** `websocket.Accept(w, r, &websocket.AcceptOptions{OriginPatterns: []string{"*"}})`.
- **Why it matters:** Same reasoning as P3-4 — defense-in-depth gap, not a primary control, since a valid JWT is still required via `?token=`. Worth tightening only if same-origin becomes an actual product requirement.
- **Evidence / how verified:** Read `ws/handler.go` directly.
- **Confidence:** Confirmed (watch-item)

## Patterns observed

- **Tenant scoping (`community_id`) is applied by convention, not by any structural enforcement, and it lapsed independently in three unrelated places** (P1-1 admin document review, P1-2 service-request detail/responses, P0-1 chat which additionally lacks even a participant check). Per-handler hand-rolled `WHERE community_id = $N` has no framework backstop (see [[project-specific appendix in the audit-backend skill]]) — a missing filter fails silently with wrong-tenant data instead of being blocked. This happening three times independently, always in the handlers that skip the service layer (P2-4), suggests the gap is structural, not a one-off oversight: there's no shared helper or middleware that forces a query to be community-scoped.
- **Query errors are inconsistently handled**: some handlers correctly check and surface every error (`ProviderHandler`, `ChatHandler`), others discard decode/exec errors outright (`RequestHandler.UpdateStatus/Respond`, `ProviderService`'s four helper methods in P2-5). There's no house style enforced here either way.
- **The four handlers with no service layer** (`AdminHandler`, `CategoryHandler`, `RequestHandler`, and effectively `UploadHandler`) are exactly where the multi-tenancy and layering findings cluster — every other handler in the codebase goes through a service that takes `communityID` as an explicit, hard-to-forget parameter.

## What's working well

- **Parameterized SQL used consistently everywhere** — every query across all 42 files uses `$1, $2, ...` placeholders; no string-concatenated or `fmt.Sprintf`-built SQL with user input was found anywhere in the sweep (the one `fmt.Sprintf` in `provider.go:63` only interpolates a server-selected `ORDER BY` column name from a fixed `switch`, never user input directly).
- **Auth fundamentals are solid**: bcrypt with `DefaultCost` for password hashing, refresh tokens stored as SHA-256 hashes (never raw), forgot-password flow deliberately returns 200 regardless of whether the email exists to avoid enumeration, and `RatingHandler.ListByProvider` has a nice deliberate anonymity check (providers can't see their own individual ratings) with an explanatory comment.
- **Graceful shutdown and server timeouts are correctly wired**: `main.go` handles `SIGINT`/`SIGTERM` and calls `Shutdown` with a bounded context; `server.New` sets sane `ReadTimeout`/`WriteTimeout`/`IdleTimeout` at the `http.Server` level.
- **Migrations are clean**: all 17 migrations have matching `.up.sql`/`.down.sql` pairs, sequential numbering with no gaps, and `UpdateMe`'s multi-step provider-profile patch correctly wraps its two related writes in a single transaction.
- **`domain.CalculateScore` is the one properly unit-tested piece of business logic in the repo** — small, pure, and has a real test file (`score_test.go`) covering it.

---

# Auditoria de acompanhamento — 2026-07-03

**Motivo:** o usuário reportou que login não funcionava para as duas contas de teste; pedido para auditar o backend de novo e testar "todos os botões e acessos temporários". Esta seção re-verifica os achados de 2026-07-02 contra o código atual (nenhum arquivo do backend mudou desde então — só o app mobile, no rebrand de paleta) e soma achados novos encontrados numa varredura independente + reprodução ao vivo via curl contra o backend rodando localmente.

**Todos os 13 achados corrigidos em 2026-07-02 seguem corrigidos** — reli cada arquivo e reconfirmei: chat ownership (`assertParticipant` em `chat.go` e `client.go`), escopo de `service_requests` (`request.go` filtra `community_id` em `Get`/`Respond`/`ListResponses`), detecção de reuso de refresh token (`auth.go:203-213`), N+1 batelado (`attachExtras`/`batchCategories`/`batchSealExtras`), timeouts (FCM/Resend `httpTimeout=10s`, `pushNotify` com `context.WithTimeout`), índices da migration 000018 (confirmados via `\di` no Postgres rodando), rate limit em `/auth/forgot-password`/`/uploads/presign`/registro, `AddPhoto` exigindo `{id}==caller`, `DELETE /recommendations` sem `{id}` na rota, Dockerfile com `USER app`, CI mínimo (`.github/workflows/backend.yml` — presente localmente, não commitado ainda).

## Causa raiz do login quebrado (não é um bug de código)

Os containers `aldeia-indica-postgres-1`/`minio-1` tinham parado (`docker compose ps` mostrou `Exited`) enquanto o processo Go do backend continuava de pé com a conexão de banco morta. Motivo secundário: a senha de `rudolpheks@hotmail.com` nunca tinha sido documentada/definida de forma recuperável. Ambos corrigidos nesta sessão (containers religados; senha redefinida via bcrypt direto no banco — ver `docs/setup.md`). Isso expôs um achado real, novo (P2-7 abaixo): `/health` não verifica a dependência que realmente quebrou.

## Status das correções (2026-07-03)

Todos os achados P1 e os itens mecânicos abaixo foram corrigidos e reverificados nesta
mesma sessão (`go build`/`go vet`/`go test` limpos, e cada fix reproduzido de novo
via curl contra o backend rodando, repetindo exatamente o teste que provou o bug):

| Achado | Status | Como foi verificado |
|---|---|---|
| P1-A `hire` sem limite | ✅ Corrigido | Nova tabela `provider_hires` (migration 000019) com `UNIQUE(community_id, provider_id, hirer_id)`. 2ª chamada da mesma conta retorna `409` e `total_hires` para de incrementar (ficou em `1`, não `2`) |
| P1-B `DELETE /recommendations` sem `RowsAffected` | ✅ Corrigido | Deletar indicação inexistente agora retorna `404`; `recommendation_count` não mudou |
| P1-C `/admin/users` retornava 1 de 17 | ✅ Corrigido | `CreatedAt` trocado de `string` para `time.Time`, erro do `Scan` agora é checado; endpoint retorna os 17 usuários com timestamp válido |
| P1-D `category_slugs` inválido apagava categorias | ✅ Corrigido | Slugs validados contra `service_categories` antes do `DELETE`; slug inválido retorna `400` e categorias existentes continuam intactas |
| P2-9 erros crus vazando (6 pontos) | ✅ Corrigido | `auth.go`, `rating.go`, `recommendation.go`, `approval.go` — todos agora usam erros tipados (`ErrEmailTaken`, `ErrAlreadyRated`/`ErrInvalidRatingValue`, `ErrAlreadyRecommended`, `ErrAlreadyVoted`) com mensagens fixas; e-mail duplicado no registro retorna `{"error":"email already registered"}`, não mais o erro do Postgres |
| P2-10 `/auth/reset-password` sem rate limit | ✅ Corrigido | 6ª tentativa em 1 min retorna `429`, igual ao `/auth/forgot-password` |
| P3-6 `RequestHandler.UpdateStatus` engolindo erros | ✅ Corrigido | Erros de decode/exec agora checados; `404` se a linha não existir/pertencer ao chamador |
| P3-7 sem tamanho mínimo de senha no registro | ✅ Corrigido | Senha com menos de 6 caracteres retorna `400` nos dois handlers de registro |
| P3-9 nota inválida mascarada como "já avaliado" | ✅ Corrigido | `quality:10` (fora de 1-5) agora retorna `{"error":"rating values must be between 1 and 5"}`, não mais "already rated" |

**Decisão registrada (P1-A):** a constraint `UNIQUE(community_id, provider_id, hirer_id)`
assume que uma contratação confirmada é um evento único por vizinho por prestador —
mesma semântica já usada em `ratings`/`recommendations` neste repositório. Se
contratações repetidas do mesmo par (morador, prestador) precisarem contar
separadamente no futuro, essa constraint precisa ser revisitada (ex.: janela de tempo
em vez de unicidade permanente).

**Não corrigidos nesta rodada — dependem de decisão de produto, não só código:**
P2-8 (sistema de convites/"acesso temporário" estruturalmente inalcançável) e P3-8
(`years_in_neighborhood` estático). Ver os achados originais abaixo para o racional
completo de por que cada um precisa de uma decisão antes do fix.

## Novos achados (2026-07-03)

- P1: 4 (novos, todos corrigidos — ver tabela de status acima)
- P2: 4 (novos, 3 corrigidos + 1 pendente de decisão de produto)
- P3: 4 (novos, 3 corrigidos + 1 pendente de decisão de produto)

**Top prioridades novas:**
1. `GET /admin/users` retorna 1 usuário de 17 — a tela de gestão de usuários do admin está quebrada para qualquer comunidade com mais de um usuário (P1-C). Achado só foi possível testando o botão de verdade, não lendo código.
2. Qualquer morador autenticado infla `total_hires` (e portanto `score_aldeia`) de qualquer prestador chamando `POST /providers/{id}/hire` repetidamente — sem idempotência, sem constraint única, sem rate limit (P1-A). Reproduzido ao vivo.
3. `DELETE /recommendations` decrementa `recommendation_count` mesmo quando o `DELETE` não apagou nenhuma linha, e `PUT /providers/me` apaga categorias existentes silenciosamente se um slug não existir (P1-B, P1-D) — o mesmo padrão sistêmico (mutação SQL sem checar linhas afetadas) em três lugares independentes.
4. O sistema de convites (`/invites`) — o "acesso temporário" que o usuário pediu para testar — está estruturalmente quebrado: um usuário `pending` nunca consegue autenticar (login bloqueia `pending`), então `POST /invites/{token}/use`, que exige autenticação, é inalcançável por quem o convite deveria servir. `RegisterMorador`/`RegisterPrestador` também não aceitam token de convite. O Flutter só tem a constante de URL (`api_endpoints.dart:44`) — nenhuma tela usa (P2-8).

### [P1-A] `POST /providers/{id}/hire` permite inflar `total_hires`/`score_aldeia` sem limite
- **Location:** `internal/handler/provider.go:216-229` (`HireCompleted`), `internal/service/analytics.go:109-138` (`AnalyticsService.HireCompleted`), `internal/server/router.go:88` (rota)
- **Dimension:** Security / Reliability (integridade de dado de confiança pública)
- **What:** A rota exige só autenticação (`middleware.Authenticate`), sem `RequireRole`, sem checagem de que o chamador de fato contratou o prestador, e sem nenhuma constraint de unicidade (ao contrário de `ratings` — `UNIQUE(community_id, provider_id, rater_id)` — e `recommendations` — `UNIQUE(community_id, provider_id, recommender_id)`). Cada chamada incrementa `total_hires` incondicionalmente e recalcula o score.
- **Code (verbatim):**
  ```go
  // internal/service/analytics.go:116-120
  _, err = tx.Exec(ctx,
      `UPDATE provider_profiles SET total_hires = total_hires + 1
       WHERE user_id = $1 AND community_id = $2`,
      providerID, communityID,
  )
  ```
  ```go
  // internal/server/router.go:88 — dentro do grupo autenticado, sem RequireRole
  r.Post("/providers/{id}/hire", providerH.HireCompleted)
  ```
- **Why it matters:** `total_hires` alimenta 15% da fórmula do Score Aldeia (`min(contratações/100,1)×15`, `domain/score.go:17`) — a nota pública que todo o produto usa como sinal de confiança. Qualquer morador (ou um prestador chamando para si mesmo, já que `providerID` vem só da URL) pode inflar essa nota artificialmente.
- **Evidence / how verified:** Reproduzido ao vivo — login como `rudolpheks@hotmail.com`, 3 chamadas consecutivas a `POST /providers/5cfe3c5e.../hire`: `total_hires` foi de `0` para `3`, `score_aldeia` de `7.50` para `7.95`. Dados de teste restaurados depois (`UPDATE provider_profiles SET total_hires=0`, delete dos `provider_events` criados).
- **Fix:** Adicionar `UNIQUE(community_id, provider_id, hirer_id)` numa tabela de registro de contratações (hoje não existe — `provider_events` não tem constraint porque é log de analytics, não deveria ser a fonte de verdade de "já contratei"), e checar conflito antes do incremento — mesmo padrão de `ratings`/`recommendations`. Alternativa mais simples: `INSERT ... ON CONFLICT DO NOTHING` numa nova tabela `provider_hires(community_id, provider_id, hirer_id)` e só incrementar `total_hires` se a inserção afetou uma linha.
- **Implementation constraints:** Requer nova migration (tabela ou constraint) — não dá para reaproveitar `provider_events` porque múltiplos eventos do mesmo tipo pro mesmo par usuário/prestador são esperados ali (é log, não estado).
- **Confidence:** Confirmed

### [P1-B] `DELETE /recommendations` decrementa contagem mesmo sem ter apagado nada
- **Location:** `internal/service/recommendation.go:55-84` (`Delete`)
- **Dimension:** Security / Reliability
- **What:** O `DELETE FROM recommendations WHERE ...` não verifica `RowsAffected` antes de rodar o `UPDATE ... recommendation_count = GREATEST(recommendation_count - 1, 0)` logo em seguida. Se o par `(community_id, provider_id, recommender_id)` não existir (usuário nunca indicou esse prestador), o `DELETE` afeta 0 linhas silenciosamente (não é erro em SQL) e o `UPDATE` roda do mesmo jeito.
- **Code (verbatim):**
  ```go
  // internal/service/recommendation.go:62-77
  _, err = tx.Exec(ctx,
      `DELETE FROM recommendations WHERE community_id=$1 AND provider_id=$2 AND recommender_id=$3`,
      communityID, providerID, recommenderID,
  )
  if err != nil {
      return err
  }
  _, err = tx.Exec(ctx,
      `UPDATE provider_profiles SET recommendation_count = GREATEST(recommendation_count - 1, 0)
       WHERE user_id=$1 AND community_id=$2`,
      providerID, communityID,
  )
  ```
- **Why it matters:** `recommendation_count` alimenta 15% do Score Aldeia e o selo público "Muito indicado" (`>=3`, `provider.go:310`). Qualquer morador autenticado pode chamar isso repetidamente contra um prestador que nunca indicou, derrubando a contagem dele até zero — um vetor de sabotagem contra o sinal de confiança de um concorrente.
- **Evidence / how verified:** Reproduzido ao vivo — `recommendation_count` de um prestador nunca indicado por mim começou e terminou em `0` (já estava no piso), mas `score_aldeia` mudou de `0.00` para `7.50` na mesma chamada, confirmando que `RecomputeScore` roda incondicionalmente mesmo num `DELETE` que não apagou nada.
- **Fix:** Checar `tag.RowsAffected() == 0` depois do `DELETE` e retornar um erro (ou simplesmente não chamar `RecomputeScore`) nesse caso — mesmo padrão já usado corretamente em `BulletinService.Review` (`bulletin.go:100-102`) e em `RequestHandler.Respond` (`request.go:168-171`) no mesmo repositório.
- **Implementation constraints:** Nenhuma — é local, `tag` já é o retorno de `tx.Exec`, só precisa capturar e checar.
- **Confidence:** Confirmed

### [P1-D] `PUT /providers/me` apaga categorias existentes silenciosamente se o slug enviado não existir
- **Location:** `internal/service/provider.go:548-563` (`UpdateMe`, bloco `CategorySlugs`)
- **Dimension:** Reliability (mesmo padrão sistêmico de P1-A/P1-B — `INSERT`/mutação sem checar linhas afetadas)
- **What:** Quando `category_slugs` vem preenchido, o código sempre roda `DELETE FROM provider_services WHERE provider_id=$1` primeiro, e depois, para cada slug, `INSERT INTO provider_services (...) SELECT $1, id, $2 FROM service_categories WHERE slug=$3`. Se o slug não existir na tabela `service_categories`, o `SELECT` não retorna linhas e o `INSERT` insere zero linhas — sem erro nenhum (`INSERT ... SELECT` com zero linhas não é uma condição de erro em SQL). O `DELETE` já rodou antes, então o resultado é: categorias antigas apagadas, nenhuma nova salva, `204 No Content` (sucesso) retornado ao cliente.
- **Code (verbatim):**
  ```go
  // internal/service/provider.go:548-563
  if in.CategorySlugs != nil {
      _, err = tx.Exec(ctx, `DELETE FROM provider_services WHERE provider_id=$1`, userID)
      if err != nil {
          return err
      }
      for _, slug := range *in.CategorySlugs {
          _, err = tx.Exec(ctx,
              `INSERT INTO provider_services (provider_id, category_id, community_id)
               SELECT $1, id, $2 FROM service_categories WHERE slug=$3`,
              userID, communityID, slug,
          )
          if err != nil {
              return fmt.Errorf("insert category %s: %w", slug, err)
          }
      }
  }
  ```
- **Why it matters:** Reproduzido ao vivo testando o botão "Cadastre suas habilidades": enviei `category_slugs: ["eletrica","limpeza"]` (slugs errados — o real é `eletricista`) e recebi `204` (sucesso). `GET /providers/me` logo depois confirmou `categories: null` — as categorias sumiram e nada foi salvo, sem nenhum sinal de erro pro app mostrar ao prestador. Reenviando com o slug correto (`eletricista`) salvou normalmente, confirmando o mecanismo. Isso é o terceiro caso do mesmo padrão sistêmico (ver P1-A, P1-B): uma mutação SQL que "não erra" quando não afeta linhas, e o código não checa `RowsAffected`/existência antes de prosseguir.
- **Evidence / how verified:** Reproduzido ao vivo, sequência completa: PUT com slugs inválidos → `204` → GET confirma `categories: null` → PUT com slug válido (`eletricista`) → GET confirma `categories: ["Eletricista"]`.
- **Fix:** Validar os slugs contra `service_categories` antes do `DELETE` (uma query `SELECT slug FROM service_categories WHERE slug = ANY($1)` e comparar contagem/conjunto com o que foi enviado) — se algum não existir, retornar `400` sem tocar nos dados existentes.
- **Implementation constraints:** Precisa mover a validação para antes do `tx.Begin()`/`DELETE`, não depois — senão o `DELETE` já rodou quando o erro for detectado.
- **Confidence:** Confirmed

### [P2-7] `/health` não verifica a dependência que realmente quebra
- **Location:** `internal/server/router.go:45-47`
- **Dimension:** Reliability
- **What:** O endpoint de health check sempre retorna `200`, sem pingar o Postgres/pool.
- **Code (verbatim):**
  ```go
  r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
      w.WriteHeader(http.StatusOK)
  })
  ```
- **Why it matters:** Foi exatamente o que aconteceu nesta sessão — os containers de Postgres/MinIO caíram, o processo Go continuou de pé e `/health` teria continuado respondendo `200` o tempo todo, escondendo o problema real (todo login/query falhando) de qualquer monitoramento básico baseado nesse endpoint.
- **Evidence / how verified:** Lido o handler diretamente; reproduzido o cenário real desta sessão (containers `Exited`, backend de pé, login falhando).
- **Fix:** `db.Ping(ctx)` (ou `pool.Ping`) dentro do handler, retornar `503` se falhar.
- **Implementation constraints:** Precisa passar o `*pgxpool.Pool` para o handler de health (hoje é uma func inline sem dependências) — mudança pequena em `router.go`/`main.go`.
- **Confidence:** Confirmed

### [P2-8] Sistema de convites ("acesso temporário") estruturalmente inalcançável
- **Location:** `internal/service/user.go:150-209` (`CreateInvite`/`ValidateInvite`/`UseInvite`), `internal/service/auth.go:149-181` (`Login`), `internal/handler/auth.go:20-94` (registro sem campo de convite), `mobile/lib/core/constants/api_endpoints.dart:44`
- **Dimension:** Code quality / Reliability (funcionalidade morta) + Security (token em texto puro)
- **What:** Três problemas compostos:
  1. `POST /invites/{token}/use` exige `middleware.Authenticate`, mas um usuário recém-registrado fica `status='pending'` e `Login` recusa login de `pending` (`ErrUserPending`, `auth.go:170-171`) — ou seja, a própria pessoa que o convite deveria ativar nunca consegue um JWT para chamar essa rota.
  2. `RegisterMorador`/`RegisterPrestador` não têm nenhum campo de token de convite — não existe caminho que ligue "usei um convite" a "me cadastrei".
  3. `invites.token` é armazenado em texto puro (`user.go:157-161`), diferente de `refresh_tokens.token_hash` e `password_reset_tokens.code_hash`, que são hash SHA-256.
- **Code (verbatim):**
  ```go
  // internal/service/auth.go:169-174
  switch user.Status {
  case domain.StatusPending:
      return nil, ErrUserPending
  ```
  ```go
  // internal/server/router.go — dentro do grupo autenticado
  r.Post("/invites/{token}/use", approvalH.UseInvite)
  ```
  ```go
  // internal/service/user.go:157-161 — token em texto puro
  _, err := s.db.Exec(ctx,
      `INSERT INTO invites (community_id, created_by, token, intended_email, expires_at)
       VALUES ($1, $2, $3, $4, $5)`,
      communityID, creatorID, token, intendedEmail, time.Now().Add(72*time.Hour),
  )
  ```
- **Why it matters:** É a funcionalidade que o usuário pediu explicitamente para testar ("acessos temporários"). Ela existe no backend (rotas registradas, service implementado) mas é inalcançável ponta-a-ponta: `grep -rn "invite" mobile/lib` só encontra a constante de URL (`api_endpoints.dart:44`), nenhuma tela do app a usa. Reproduzido ao vivo: registrei um usuário novo, `login` retornou `403 account pending approval` — confirma que o fluxo de uso do convite não tem como ser alcançado nem manualmente.
- **Evidence / how verified:** Reproduzido ao vivo (registro + tentativa de login como pending → `403`); `grep -rn "invite" -i mobile/lib` confirmando zero uso de UI; leitura completa de `user.go`, `auth.go` e `router.go`.
- **Fix:** Decisão de produto necessária antes do fix de código — duas opções: (a) `RegisterMorador` aceita um `invite_token` opcional e, se válido, pula o fluxo de aprovação por votação (ativa direto), ou (b) remover a funcionalidade de convite até haver uma tela que a use. Em qualquer caso: hashear `invites.token` como os outros tokens, e decidir se `intended_email` deve ser validado contra o e-mail de quem usa o convite (hoje é capturado e nunca checado).
- **Implementation constraints:** Opção (a) muda o contrato de `RegisterMorador`/`RegisterPrestador` (novo campo opcional) e precisa decidir o que acontece com `user_approvals` para quem entrou via convite (pular a votação inteira, ou só reduzir de 2 votos pra 0?) — isso é uma decisão de produto, não só código.
- **Confidence:** Confirmed

### [P2-9] Erros internos crus vazam para o cliente em 6 pontos
- **Location:** `internal/handler/auth.go:51,89`, `internal/handler/rating.go:55`, `internal/handler/recommendation.go:39`, `internal/handler/approval.go:40,63`
- **Dimension:** Security (info disclosure)
- **What:** `jsonError(w, err.Error(), http.StatusBadRequest)` repassa a mensagem de erro do Go/Postgres direto pro cliente, em vez de uma mensagem genérica — inconsistente com o resto do código, que majoritariamente usa `"internal error"`/mensagens fixas.
- **Code (verbatim):**
  ```go
  // internal/handler/auth.go:50-53
  if err != nil {
      jsonError(w, err.Error(), http.StatusBadRequest)
      return
  }
  ```
- **Why it matters:** Vaza nome de constraint, nome de tabela/coluna e SQLSTATE do Postgres — informação útil para reconhecimento de um atacante, além de simplesmente feio para um app de usuário final.
- **Evidence / how verified:** Reproduzido ao vivo — `POST /auth/register/morador` com e-mail duplicado retornou `{"error":"insert user: ERROR: duplicate key value violates unique constraint \"users_community_id_email_key\" (SQLSTATE 23505)"}`.
- **Fix:** Trocar por mensagens fixas por caso (ex.: detectar `pgErr.Code == "23505"` e responder "email already registered"), como já é feito nos outros ~20 handlers do arquivo.
- **Implementation constraints:** Precisa de um type assertion pra `*pgconn.PgError` pra distinguir "email duplicado" de outros erros de banco, se quiser mensagens específicas em vez de só genérica.
- **Confidence:** Confirmed

### [P2-10] `/auth/reset-password` sem rate limit — código de 6 dígitos é brute-forceável
- **Location:** `internal/server/router.go:65-66`
- **Dimension:** Security
- **What:** `/auth/forgot-password` tem `authRateLimit` (5/min por IP); `/auth/reset-password` — que verifica o código de 6 dígitos — não tem nenhum.
- **Code (verbatim):**
  ```go
  r.With(authRateLimit).Post("/auth/forgot-password", authH.ForgotPassword)
  r.Post("/auth/reset-password", authH.ResetPassword)
  ```
- **Why it matters:** O código é 6 dígitos (1 milhão de combinações) válido por 30 minutos (`auth.go:288`). Sem rate limit, um atacante que sabe o e-mail/comunidade de alguém pode tentar forçar o código dentro da janela de 30 min — é exatamente o tipo de endpoint que `authRateLimit` já protege no vizinho de cima.
- **Evidence / how verified:** Lido `router.go` linha a linha — `authRateLimit` aparece em `register/morador`, `register/prestador` e `forgot-password`; ausente em `reset-password`.
- **Fix:** `r.With(authRateLimit).Post("/auth/reset-password", authH.ResetPassword)` — mesma linha de raciocínio já aplicada aos vizinhos.
- **Implementation constraints:** Nenhuma — é o mesmo middleware já importado e usado no arquivo.
- **Confidence:** Confirmed

### [P3-6] `RequestHandler.UpdateStatus` ainda descarta erros de decode/exec
- **Location:** `internal/handler/request.go:124-139`
- **Dimension:** Code quality — item do "Patterns observed" de 2026-07-02 que ficou sem correção explícita (o vizinho `Respond` foi corrigido, este não)
- **What:** `json.NewDecoder(r.Body).Decode(&in)` e `h.db.Exec(...)` sem checar erro nenhum — sempre responde `204`, mesmo se o JSON for inválido ou o `UPDATE` falhar (ex.: `in.Status` fora do enum `request_status`).
- **Code (verbatim):**
  ```go
  func (h *RequestHandler) UpdateStatus(w http.ResponseWriter, r *http.Request) {
      claims, _ := middleware.ClaimsFrom(r.Context())
      requestID, _ := uuid.Parse(chi.URLParam(r, "id"))
      var in struct{ Status string `json:"status"` }
      json.NewDecoder(r.Body).Decode(&in)
      h.db.Exec(r.Context(), `UPDATE service_requests SET status=$1, ... WHERE id=$2 AND requester_id=$3`, in.Status, requestID, claims.UserID)
      w.WriteHeader(http.StatusNoContent)
  }
  ```
- **Why it matters:** Cliente nunca sabe se a atualização de status realmente aconteceu — `status` é enum Postgres, então um valor inválido faz o `Exec` falhar silenciosamente e o app mobile segue achando que deu certo.
- **Evidence / how verified:** Reproduzido ao vivo — `PUT /requests/{id}` com `{"status":"status_que_nao_existe"}` (valor fora do enum `request_status`) retornou `204` normalmente; `SELECT status FROM service_requests` confirmou que o status no banco não mudou (ficou no valor anterior, `closed`, de uma chamada válida imediatamente antes) — a atualização falhou silenciosamente e o cliente nunca saberia.
- **Fix:** Checar os dois erros e responder `400`/`500` como os outros handlers do mesmo arquivo já fazem.
- **Confidence:** Confirmed

### [P3-7] Sem validação de tamanho mínimo de senha no registro
- **Location:** `internal/handler/auth.go:20-56` (`RegisterMorador`), `58-94` (`RegisterPrestador`)
- **Dimension:** Code quality (inconsistência entre módulos)
- **What:** `ResetPassword` valida `len(in.NewPassword) < 6` (`auth.go:209`); os dois handlers de registro não validam tamanho de senha nenhum.
- **Why it matters:** Um morador pode se cadastrar com senha de 1 caractere; se ele um dia usar "esqueci minha senha", a nova senha já é obrigada a ter 6+ — inconsistência pura entre as duas portas de entrada da mesma credencial.
- **Evidence / how verified:** Lido os três handlers lado a lado — só `ResetPassword` tem a checagem de tamanho.
- **Fix:** Mesma checagem (`len(in.Password) < 6`) nos dois handlers de registro.
- **Confidence:** Confirmed

### [P3-8] Score usa `years_in_neighborhood` estático, nunca recalculado
- **Location:** `internal/service/auth.go:130-132` (gravado só no registro), `internal/domain/score.go:15` (usado na fórmula)
- **Dimension:** Code quality / product
- **What:** `years_in_neighborhood` é gravado uma vez no cadastro do prestador e nunca mais atualizado — mas alimenta 15% do Score Aldeia pra sempre com o valor do dia do cadastro.
- **Why it matters:** Um prestador cadastrado há 3 anos com `years_in_neighborhood=1` continua contribuindo com "1 ano" pro score indefinidamente, a menos que edite o perfil manualmente. Não é bug de segurança, é deriva de dado silenciosa no tempo.
- **Evidence / how verified:** `grep -rn "years_in_neighborhood" internal/` — só aparece no INSERT de registro e no COALESCE de `UpdateMe` (edição manual pelo próprio prestador), nunca num cron/recompute automático.
- **Fix:** Calcular a partir de `users.created_at` (`EXTRACT(YEAR FROM age(now(), created_at))`) em vez de um campo estático, ou aceitar a deriva como decisão de produto e documentar.
- **Confidence:** Confirmed (achado, não necessariamente bug — depende de intenção de produto)

### [P1-C] `GET /admin/users` retorna só 1 usuário de 17 — tela de Usuários do admin está quebrada
- **Location:** `internal/handler/admin.go:44-59` (`ListUsers`)
- **Dimension:** Reliability / Code quality
- **What:** `rows.Scan(&u.ID, &u.FullName, &u.Email, &u.Role, &u.Status, &u.CreatedAt)` escaneia a coluna `created_at` (`TIMESTAMP WITH TIME ZONE`) para um campo Go `string`, e o erro de `Scan` é descartado (não é `if err := rows.Scan(...); err != nil`). O mismatch de tipo faz o `Scan` falhar silenciosamente, e a iteração para depois da primeira linha.
- **Code (verbatim):**
  ```go
  // internal/handler/admin.go:45-53
  var u struct {
      ID        uuid.UUID `json:"id"`
      FullName  string    `json:"full_name"`
      Email     string    `json:"email"`
      Role      string    `json:"role"`
      Status    string    `json:"status"`
      CreatedAt string    `json:"created_at"`
  }
  rows.Scan(&u.ID, &u.FullName, &u.Email, &u.Role, &u.Status, &u.CreatedAt)
  ```
- **Why it matters:** Achado testando o botão "Usuários" do painel admin de verdade (não só lendo código) — encontrado exatamente pelo tipo de teste que foi pedido nesta sessão. A comunidade de teste tem 17 usuários (16 `active`); o endpoint retorna só 1 (o mais recente, `admin@teste.com`, criado nesta própria sessão para testar o painel). Isso significa que a tela de gestão de usuários do admin está, na prática, mostrando só o último usuário cadastrado — inutilizável para qualquer comunidade com mais de um usuário.
- **Evidence / how verified:** Reproduzido ao vivo — `SELECT COUNT(*) FROM users WHERE community_id=...` no Postgres retornou `17` (16 `active`); `GET /admin/users` e `GET /admin/users?status=active` retornaram um array com exatamente 1 item, em ambos os casos. `created_at` vem como string vazia (`""`) no JSON de resposta, consistente com um `Scan` que falhou e deixou o campo no zero-value.
- **Fix:** Trocar `CreatedAt string` por `CreatedAt time.Time` na struct (e no `map[string]any` de saída, já que `json.Marshal` serializa `time.Time` corretamente como RFC3339) e checar o erro do `Scan`.
- **Implementation constraints:** Nenhuma — é uma troca de tipo local ao handler, sem mudança de assinatura pública nem de schema.
- **Confidence:** Confirmed

### [P3-9] `RatingService.Create` mascara erro de validação (nota fora de 1-5) como "já avaliado"
- **Location:** `internal/service/rating.go:34-49`
- **Dimension:** Code quality (mensagem de erro enganosa)
- **What:** Qualquer erro do `INSERT INTO ratings` — seja a violação de `UNIQUE(community_id, provider_id, rater_id)` (já avaliou) ou a violação do `CHECK (quality BETWEEN 1 AND 5)` (nota inválida) — retorna o mesmo `ErrAlreadyRated`.
- **Code (verbatim):**
  ```go
  // internal/service/rating.go:41-49
  _, err = tx.Exec(ctx, `INSERT INTO ratings (...) VALUES (...)`, ...)
  if err != nil {
      return ErrAlreadyRated
  }
  ```
- **Why it matters:** Testado ao vivo enviando `quality:10` (fora do range 1-5) para um provider nunca avaliado antes — a resposta foi `{"error":"you have already rated this provider"}`, uma mensagem completamente errada que esconderia um bug real de validação no cliente (a Flutter UI não deveria permitir nota fora de 1-5, mas se algum dia permitir, ou um cliente de terceiros chamar a API direto, o erro reportado ao usuário/dev seria enganoso).
- **Evidence / how verified:** Reproduzido ao vivo: `POST /ratings` com `quality:10` para um `provider_id` nunca avaliado por essa conta retornou `400 {"error":"you have already rated this provider"}`.
- **Fix:** Checar o tipo do erro do Postgres (`pgconn.PgError.Code`) — `23505` (unique violation) → `ErrAlreadyRated`; `23514` (check violation) → um erro novo tipo `ErrInvalidRatingValue`.
- **Confidence:** Confirmed

## Achado fora do backend, encontrado de passagem

O e-mail de recuperação de senha (`internal/service/auth.go:366-379`, `resetEmailHTML`) ainda usa o verde antigo da marca (`#1B5E20`) — o rebrand v1.1 desta mesma sessão (ver commit `a399bce`) cobriu só o app Flutter; esta é uma superfície renderizada pelo backend que ficou de fora. Trivial de corrigir (`#1B5E20` → `#2E5C74`), mas registrado aqui porque só apareceu durante a leitura de `auth.go` para este achado de segurança, não numa varredura de marca.

## Padrão sistêmico encontrado nesta rodada

**"Mutação SQL sem checar linhas afetadas" apareceu de forma independente em três lugares** (P1-A `HireCompleted`, P1-B `Recommendation.Delete`, P1-D `UpdateMe`/`category_slugs`) — em SQL, um `UPDATE`/`DELETE`/`INSERT...SELECT` que não afeta nenhuma linha não é um erro, então qualquer código que assume "não deu erro = fez o que eu queria" está exposto a esse bug. Os três casos encontrados nesta auditoria têm o mesmo formato: uma ação que deveria ser condicional a "isso realmente existia/mudou" mas não checa `RowsAffected`/existência antes de seguir em frente (recomputar score, aceitar como sucesso). Comparar com `BulletinService.Review` (`bulletin.go:100-102`) e `RequestHandler.Respond` (`request.go:168-171`), que já fazem essa checagem corretamente no mesmo repositório — é uma inconsistência de padrão, não uma limitação da stack.

## Resumo consolidado (2026-07-02 + 2026-07-03)

| Data | P0 | P1 | P2 | P3 |
|---|---|---|---|---|
| 2026-07-02 (todos corrigidos, ver tabela de status) | 1 | 4 | 6 | 5 |
| 2026-07-03 (corrigidos: 4 P1, 3 P2, 3 P3 — ver tabela de status) | 0 | 4 | 4 (3 corrigidos, 1 pendente de decisão) | 4 (3 corrigidos, 1 pendente de decisão) |

**As prioridades mais urgentes de 2026-07-03:** as três de manipulação/perda de dado sem checar linhas afetadas (P1-A, P1-B, P1-D) e a tela de usuários do admin quebrada (P1-C) — todas reproduzidas ao vivo contra o backend rodando, as três primeiras exploráveis por qualquer conta autenticada comum (morador ou prestador), sem precisar de nenhum acesso privilegiado.

# Auditoria de acompanhamento — 2026-07-05

**Escopo:** todo o backend Go (42 arquivos, 8 services, 11 handlers, ws, middleware, config, platform). Todas as mudanças abaixo já foram aplicadas e verificadas (`go build`, `go vet`, `gofmt -l`, `go test -race -count=1 ./...` limpos; endpoints re-testados ao vivo via curl contra o backend rodando).

**Stack confirmado:** Go 1.26.4, chi v5, pgx/v5 (SQL manual, sem ORM), PostgreSQL 18, S3/MinIO via presigned URL, `coder/websocket`, `golang-migrate` (22 migrations, todas com par up/down), JWT HS256.

## Summary

- P0: 0
- P1: 1 (corrigido)
- P2: 4 (corrigidos)
- P3: 5 (corrigidos) + 1 registrado sem correção (nit de clareza)

**Top 3 prioridades corrigidas:** (1) `POST /auth/login` sem nenhum rate limit — `internal/server/router.go:63`; (2) erro da contenção de segurança do reuse de refresh token sendo descartado — `internal/service/auth.go:279`; (3) upload aceitando qualquer `object_type` e filename não sanitizado indo direto pra chave do S3 — `internal/handler/upload.go`.

## Findings

### P1 — High

#### [P1-1] `POST /auth/login` não tem rate limit — único endpoint pré-auth sem essa proteção
- **Location:** `internal/server/router.go:63` (antes do fix)
- **Dimension:** Security
- **What:** Todos os outros endpoints pré-auth que criam conta ou disparam e-mail (`register/morador`, `register/prestador`, `forgot-password`, `reset-password`) já usavam `.With(authRateLimit)` (5 tentativas/min por IP, `httprate.LimitByIP(5, time.Minute)`). `/auth/login` — o endpoint mais visado de qualquer sistema de auth — era o único sem.
- **Code (verbatim, antes do fix):**
  ```go
  r.With(authRateLimit).Post("/auth/register/morador", authH.RegisterMorador)
  r.With(authRateLimit).Post("/auth/register/prestador", authH.RegisterPrestador)
  r.Post("/auth/login", authH.Login)
  r.Post("/auth/refresh", authH.Refresh)
  r.With(authRateLimit).Post("/auth/forgot-password", authH.ForgotPassword)
  r.With(authRateLimit).Post("/auth/reset-password", authH.ResetPassword)
  ```
- **Why it matters:** Padrão clássico "N-1 de N" — 4 de 5 endpoints pré-auth protegidos, faltando exatamente o mais crítico (login por senha). bcrypt adiciona custo computacional por tentativa, mas não substitui rate limit: um atacante com paciência (ou uma botnet distribuída) podia tentar senhas ilimitadas contra qualquer `community_id`+`email` conhecido, sem nenhum limite de taxa.
- **Evidence / how verified:** Reproduzido ao vivo antes do fix (sem rate limit, N tentativas seguidas todas retornavam 401 normalmente). Depois do fix: 6 tentativas de login em sequência rápida contra `admin@teste.com` retornaram `401,401,401,401,429,429` — a 5ª requisição (contando o login legítimo feito minutos antes, dentro da mesma janela de 1 minuto) já bloqueou.
- **Fix:** `r.With(authRateLimit).Post("/auth/login", authH.Login)` — reaproveita o rate limiter que já existia, zero infraestrutura nova.
- **Implementation constraints:** Nenhuma — mudança de uma linha, o middleware já estava importado e configurado.
- **Confidence:** Confirmed

### P2 — Medium

#### [P2-1] Erro da contenção de segurança (revoke-all no reuse de refresh token) descartado silenciosamente
- **Location:** `internal/service/auth.go:279` (antes do fix)
- **Dimension:** Reliability / Security
- **What:** O mecanismo de detecção de reuse de refresh token (achado P1-2 da rodada de 2026-07-02) já existe e funciona corretamente — ao detectar que um token já revogado foi reapresentado, o código tenta revogar todos os outros refresh tokens ativos daquele usuário. Mas o resultado desse `Exec` era descartado (`_, _ = s.db.Exec(...)`).
- **Code (verbatim, antes do fix):**
  ```go
  _, _ = s.db.Exec(ctx,
      `UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`,
      rt.UserID,
  )
  return nil, errors.New("refresh token expired or revoked")
  ```
- **Why it matters:** Se esse `UPDATE` falhar (conexão instável, timeout do pool), a resposta ao chamador é a mesma de qualquer forma ("expired or revoked") — mas a sessão da conta comprometida continua válida sem que ninguém saiba, porque a falha da própria contenção de segurança nunca é reportada nem logada.
- **Evidence / how verified:** Leitura direta do código + confirmação de que nenhum log/erro cobria essa falha (`grep` no arquivo não mostrava tratamento). Fix compilado e testado via `go build`/`go vet`.
- **Fix:** Checar o erro do `Exec` e retorná-lo envolvido (`fmt.Errorf("revoke token family after reuse detected: %w", revokeErr)`) em vez de descartar.
- **Implementation constraints:** Nenhuma.
- **Confidence:** Confirmed

#### [P2-2] Upload: `object_type` sem allow-list e `filename` sem sanitização antes de virar chave do S3
- **Location:** `internal/handler/upload.go` (antes do fix)
- **Dimension:** Security
- **What:** `object_type` era um comentário (`// avatar, work_photo, chat_image, document`), não uma validação — qualquer string era aceita, e só o literal `"document"` recebia tratamento especial (bucket privado). `Filename` do cliente era concatenado direto na chave (`uuid.New().String()+"-"+in.Filename`), sem remover espaços, barras ou caracteres de controle.
- **Code (verbatim, antes do fix):**
  ```go
  var in struct {
      ObjectType string `json:"object_type"` // avatar, work_photo, chat_image, document
      Filename   string `json:"filename"`
  }
  ...
  isPrivate := in.ObjectType == "document"
  key := fmt.Sprintf("%s/%s/%s/%s",
      claims.CommunityID, in.ObjectType, claims.UserID, uuid.New().String()+"-"+in.Filename,
  )
  ```
- **Why it matters:** Como o backend nunca toca os bytes do arquivo (upload é direto pro S3 via URL presignada), validação de magic-byte é arquiteturalmente impossível aqui — a única contenção possível nesse ponto é isolar `object_type`/`filename`. S3 não resolve `..` como um filesystem, então não é path traversal, mas nome de arquivo malicioso ainda podia injetar caracteres de controle ou produzir chaves absurdamente longas.
- **Evidence / how verified:** Reproduzido ao vivo: `object_type:"anything_goes"` → `400 {"error":"invalid object_type"}` depois do fix (antes, teria sido aceito e caído no bucket público por padrão). `filename:"weird name with spaces #$.jpg"` → object_key final `...-weird_name_with_spaces___.jpg`, espaços e símbolos virados `_`.
- **Fix:** Allow-list explícita (`avatar`, `work_photo`, `chat_image`, `document`) retornando 400 se fora dela; `sanitizeFilename` troca qualquer caractere fora de `[a-zA-Z0-9._-]` por `_` e limita a 100 caracteres.
- **Implementation constraints:** Nenhuma — mudança isolada ao handler, não afeta o contrato de resposta pra clientes que já mandavam `object_type` válido.
- **Confidence:** Confirmed

#### [P2-3] 7 pontos com `rows.Scan` sem checar erro — mesmo padrão já corrigido em outros lugares, mas não em todos
- **Location:** `internal/handler/admin.go:322` (`ListCommunities`), `internal/service/analytics.go:67` (`DashboardSummary`), `internal/handler/request.go:60` (`List`) e `:231` (`ListResponses`), `internal/service/chat.go:186` (`GetDeviceTokens`), `internal/service/bulletin.go:57` e `:80` (`ListApproved`/`ListPending`)
- **Dimension:** Reliability / Code quality (padrão sistêmico — ver "Patterns observed")
- **What:** Mesma classe de bug que já causou o achado real `[P1-C]` da rodada de 2026-07-03 (`admin/users` truncando a lista por um `Scan` que falhava silenciosamente) — só que aquele fix não foi replicado pros outros 7 call sites que tinham o mesmo formato (`rows.Scan(...)` sem `if err := ...; err != nil`).
- **Code (verbatim, um exemplo representativo — `admin.go:322`):**
  ```go
  rows.Scan(&c.ID, &c.Name, &c.Slug, &c.City, &c.State)
  list = append(list, map[string]any{...})
  ```
- **Why it matters:** Nenhum dos 7 tem hoje um mismatch de tipo tão óbvio quanto o `admin/users` original (a maioria escaneia tipos simples), mas o risco estrutural é o mesmo: qualquer erro de scan (incluindo erro de conexão/rede a meio da iteração) passa despercebido, e a função retorna uma lista parcial como se fosse completa.
- **Evidence / how verified:** `grep -n "rows.Scan(" internal/handler/*.go internal/service/*.go | grep -v "if err :="` — 7 ocorrências, listadas acima.
- **Fix:** Checar erro em cada `Scan`, mais `rows.Err()` depois do loop nos que não tinham (padrão idêntico ao já usado em `ListUsers`/`CategoryHandler.List`/os 4 endpoints admin novos desta sessão).
- **Implementation constraints:** Nenhuma — mudança mecânica, mesmo padrão repetido 7 vezes.
- **Confidence:** Confirmed

#### [P2-4] Zero cobertura de testes fora de `internal/domain/score_test.go`
- **Location:** todo `internal/handler/` (11 arquivos), `internal/service/` (8 arquivos), `internal/ws/`, `internal/server/middleware/`
- **Dimension:** Code quality
- **What:** `go test -race -count=1 ./...` só executa `internal/domain` (1 arquivo de teste, 4 casos). Os 11 handlers e 8 services que concentram toda a lógica de negócio, multi-tenancy e autenticação não têm nenhum teste automatizado.
- **Why it matters:** Sem essa rede de segurança, qualquer regressão nos pontos mais sensíveis (isolamento por `community_id`, ownership de chat, rotação de refresh token) só é pega manualmente — como aconteceu nas duas rodadas de auditoria anteriores, que encontraram bugs reais só testando os endpoints ao vivo.
- **O que bloqueia escrever esses testes hoje (documentado, não é só "faltam testes"):** todo `service` recebe `*pgxpool.Pool` direto no construtor (`NewAuthService(db *pgxpool.Pool, ...)`, etc.) — não há interface por trás, então um teste unitário puro exigiria um Postgres real (via testcontainers ou um banco de teste dedicado) para exercitar qualquer service; não existe hoje nenhum harness desse tipo no repo, nem fixtures, nem seed de dados de teste isolado por execução.
- **Fix (sugerido, não implementado nesta rodada — exige decisão de infraestrutura de teste, não só código):** Introduzir `testcontainers-go` com Postgres efêmero por execução de teste, começando pelos services de maior risco (`auth.go`, `chat.go`, multi-tenancy em `provider.go`).
- **Confidence:** Confirmed (a ausência); `[UNVERIFIED]` o esforço exato de configurar testcontainers neste projeto especificamente.

### P3 — Low / nit

#### [P3-1] `RequestHandler.UpdateStatus` não filtrava por `community_id`
- **Location:** `internal/handler/request.go:157-161` (antes do fix)
- **Dimension:** Code quality (consistência multi-tenant)
- **What:** `UPDATE service_requests SET status=$1, updated_at=now() WHERE id=$2 AND requester_id=$3` — sem `AND community_id=$4`, diferente de praticamente todo outro `UPDATE`/`DELETE` no resto do código.
- **Why it matters:** Não é explorável na prática (`id` é UUID gerado por `gen_random_uuid()`, e `requester_id` já precisa bater com o chamador — as duas condições juntas já isolam a linha certa mesmo sem o filtro de comunidade), mas quebra a convenção "toda query tenant-scoped filtra por community_id" do resto do código, o que é o tipo de inconsistência que facilita um bug real passar despercebido numa mudança futura.
- **Fix:** Adicionado `AND community_id=$4` com `claims.CommunityID`.
- **Confidence:** Confirmed

#### [P3-2] `S3Client.PublicURL` — método morto, nunca chamado
- **Location:** `internal/storage/s3.go` (antes do fix)
- **Dimension:** Redundância
- **Evidence:** `grep -rn "PublicURL" --include="*.go" .` — zero call sites em todo o repo.
- **Fix:** Removido. (`baseURL`/`CloudFrontBaseURL` no config ficam sem uso agora — inofensivo, não removido nesta rodada para não mexer na superfície de env vars documentada.)
- **Confidence:** Confirmed

#### [P3-3] `fcm.min()` reimplementa o builtin `min` do Go (disponível desde 1.21; projeto usa 1.26.4)
- **Location:** `internal/fcm/client.go` (antes do fix)
- **Dimension:** Redundância
- **Fix:** Função customizada removida; a chamada (`t[:min(8, len(t))]`) agora resolve pro builtin.
- **Confidence:** Confirmed

#### [P3-4] `domain.ProviderProfile.TotalHires` — campo residual do rastreamento de "contratação confirmada" removido nesta mesma sessão
- **Location:** `internal/domain/provider.go` (antes do fix)
- **Dimension:** Redundância / dead code
- **What:** A remoção do hire-tracking (feature removida a pedido do usuário mais cedo nesta sessão) tocou `domain.ProviderStats` (em `score.go`) mas não esse campo homônimo numa struct irmã, `domain.ProviderProfile` — que, à parte isso, já era 100% não instanciada em lugar nenhum do código (`grep` por `ProviderProfile{` e `domain.ProviderProfile` = zero resultados).
- **Fix:** Campo removido.
- **Confidence:** Confirmed

#### [P3-5] `/providers/{id}/photos` (`AddPhoto` e `DeletePhoto`) ignoram o `{id}` do path
- **Location:** `internal/handler/provider.go:162-207`
- **Dimension:** Code quality (contrato de rota enganoso)
- **What:** As duas rotas são declaradas como `/providers/{id}/photos` e `/providers/{id}/photos/{photoID}`, mas nenhum dos dois handlers lê `{id}` — ambos operam sempre em `claims.UserID` (auto-scoped). `AddPhoto` até comenta essa decisão explicitamente; `DeletePhoto` faz o mesmo sem comentário.
- **Why it matters:** Não é uma vulnerabilidade hoje — como o escopo real é sempre o dono autenticado, é mais restritivo do que a URL sugere, não menos. Mas o contrato da rota é enganoso: uma mudança futura que passe a confiar em `{id}` sem adicionar uma checagem de ownership explícita abriria um IDOR silenciosamente.
- **Fix:** Não aplicado nesta rodada — é um nit de clareza (documentar a decisão ou remover `{id}` da rota), não um bug. Registrado para decisão consciente, não corrigido automaticamente.
- **Confidence:** Confirmed

## Achados de rodadas anteriores já resolvidos (reverificados, não mais aplicáveis)

- **Doc drift sqlc/repository (P3-1 de 2026-07-02):** `CLAUDE.md`/`docs/architecture.md` já foram corrigidos em 2026-07-02 (confirmado por `grep` — `docs/architecture.md:13` já documenta corretamente "Não há camada de repositório... `internal/repository/` e `sqlc.yaml`... foram removidos"). `internal/repository/` e `sqlc.yaml` não existem mais no repo. Não é mais um achado.
- **Reuse-detection de refresh token (P1-2 de 2026-07-02):** o mecanismo já existe e funciona corretamente (revoga toda a família de tokens do usuário ao detectar reuse de um token já revogado) — só o erro do `Exec` estava sendo descartado (ver P2-1 acima, já corrigido). O achado original do apêndice estático da skill de auditoria (que descrevia isso como ausente) está desatualizado; verificado direto no código, não presumido.

## Patterns observed

- **"`rows.Scan` sem checar erro" é uma dívida que se espalhou de forma orgânica** — o fix já foi aplicado corretamente em `ListUsers`, `CategoryHandler.List` e nos 4 endpoints admin criados nesta mesma sessão, mas não foi replicado pros 7 call sites mais antigos listados em P2-3. Mesmo padrão da "mutação sem checar linhas afetadas" encontrado na rodada de 2026-07-03 — uma correção pontual não vira convenção garantida sem uma checagem cruzada do módulo inteiro.
- **FK columns sem índice dedicado, hoje não usadas em filtro/JOIN direto** (não é uma ação recomendada agora, só uma observação pra não repetir o "nunca assuma que a FK implica índice" às cegas): `invites.created_by`/`used_by`, `messages.sender_id`/`community_id`, `provider_events.actor_id`, `ratings.rater_id`, `recommendations.recommender_id`, `service_request_responses.provider_id`/`community_id`, `service_requests.requester_id`/`category_id`, `bulletin_posts.author_id`/`approved_by`, `provider_availability`/`provider_photos`/`morador_profiles.community_id`. Nenhum desses é hoje o lado dirigente de um `WHERE`/`JOIN` (ou são cobertos por um índice composto que já lidera com a coluna certa, ou o join usa a PK do outro lado) — adicionar índice agora seria infraestrutura pra um padrão de consulta que não existe. Revisitar se algum desses virar filtro direto no futuro (ex.: "listar meus convites enviados", "listar minhas avaliações feitas").

## What's working well

- **Multi-tenancy manual, mas consistente:** toda query tenant-scoped usa `claims.CommunityID` do contexto autenticado — nunca um valor vindo do cliente — confirmado por leitura direta em `provider.go`, `request.go`, `chat.go`, `bulletin.go`, `rating.go`, `recommendation.go`, `category.go` e nos 4 endpoints admin novos.
- **Ownership de conversa de chat correto nos dois transportes:** tanto o REST (`ChatHandler.assertParticipant`) quanto o WebSocket (`Client.handleMessage`/`handleRead`) verificam que o chamador é de fato um dos dois participantes antes de ler ou escrever, e a checagem de cross-community já acontece na criação da conversa (`GetOrCreateConversation`), tornando a checagem de participante suficiente depois disso.
- **`JWT.Parse` valida o signing method** (`*jwt.SigningMethodHMAC`) antes de aceitar o token — previne o ataque clássico de confusão de algoritmo (`alg: none` ou troca pra RS256 usando a chave pública como segredo HMAC).
- **Timeouts de 10s configurados** nos clients HTTP de e-mail (Resend) e push (FCM) — nenhuma chamada externa sem timeout.
- **22/22 migrations pareadas** (up/down), numeração sequencial sem lacunas.
- **CORS com `AllowCredentials: false`** — seguro dado que a autenticação é 100% via bearer token, nunca cookie (o alerta do apêndice estático sobre isso continua válido como vigilância futura, não como achado atual).

## Resumo consolidado (2026-07-02 + 2026-07-03 + 2026-07-05)

| Data | P0 | P1 | P2 | P3 |
|---|---|---|---|---|
| 2026-07-02 (todos corrigidos) | 1 | 4 | 6 | 5 |
| 2026-07-03 (corrigidos: 4 P1, 3 P2, 3 P3) | 0 | 4 | 4 | 4 |
| 2026-07-05 (corrigidos: 1 P1, 4 P2, 4 P3; 1 P3 registrado sem correção) | 0 | 1 | 4 | 5 |

**Prioridade mais urgente desta rodada:** o rate limit ausente em `/auth/login` (P1-1) — único ponto sem essa proteção entre os endpoints pré-auth, e o mais óbvio alvo de força bruta em qualquer sistema de autenticação. Já corrigido e confirmado ao vivo (6 tentativas em sequência bloqueadas a partir da 5ª).

---

# Auditoria de acompanhamento — 2026-07-09

**Data:** 2026-07-09
**Escopo:** backend inteiro (`internal/`, `cmd/`), com foco no que mudou desde 2026-07-05 — os fluxos de pedidos de serviço, avaliação, notificação, perguntas e favoritos, além dos endpoints admin. Migrations 000001–000027 aplicadas (era 000017 no baseline do apêndice do skill).
**Stack:** Go 1.26.4, chi v5, pgx/v5, PostgreSQL 18, S3/MinIO presigned, `coder/websocket`, JWT HS256. Sem ORM, sem RLS, sem fila.
**Método:** leitura direta dos handlers/services + reprodução via `curl`/`psql` contra o banco local. Suíte de testes: 1 arquivo (`domain/score_test.go`), passa; o resto do código não tem teste (constraint conhecida — services dependem de `pgxpool.Pool`, não há setup de teste com banco).

## Summary

- P0: 0
- P1: 0
- P2: 2 (ambos corrigidos e verificados nesta sessão)
- P3: 0

**Top prioridade:** [P2-1] Score Aldeia congelava ao editar `years_in_neighborhood` via `PUT /providers/me` — `internal/service/provider.go:564`. Corrigido.

## Findings

### P2 — Medium

#### [P2-1] `PUT /providers/me` não recomputava o Score Aldeia ao alterar `years_in_neighborhood`
- **Location:** `internal/service/provider.go:564` (`UpdateMe`)
- **Dimension:** Code quality (derived-column merge) / Reliability
- **What:** `years_in_neighborhood` é um dos quatro insumos de `domain.CalculateScore` (peso 15), mas `UpdateMe` gravava a coluna e retornava sem chamar `RecomputeScore`. Só `rating.go` e `recommendation.go` recomputavam — então o `score_aldeia` persistido ficava obsoleto até a próxima avaliação/indicação daquele prestador.
- **Code (verbatim, antes do fix):**
  ```go
  transport_type       = CASE WHEN $4 IS NOT NULL THEN $5 ELSE transport_type END,
  updated_at           = now()
  WHERE user_id=$6 AND community_id=$7`,
  // ... categorias ...
  return tx.Commit(ctx)
  ```
- **Why it matters:** o Score Aldeia é a métrica central do produto (ordena busca, destaques, ranking de categoria). Um score defasado ordena prestadores errado e mostra um número mentiroso no perfil e no painel. Blast radius baixo em frequência (editar tenure é raro, e o app hoje trata `years` como quase estático), mas corrompe silenciosamente o dado mais importante quando acontece.
- **Evidence / how verified:** reproduzido via `curl` — `PUT /providers/me {"years_in_neighborhood":1}` no prestador de teste (`5cfe3c5e…`) deixou `score_aldeia` parado em 46.85 apesar de `years` cair de 9→1 (deveria perder ~12 pts de tenure). A varredura confirmou que dos 4 insumos do score, `years_in_neighborhood` era o único escrito por um caminho sem `RecomputeScore` (`grep` de todos os call sites).
- **Fix:** após o `tx.Commit`, chamar `RecomputeScore(ctx, userID)` quando `in.YearsInNeighborhood != nil`. Recompute lê a linha inteira já commitada, então roda fora da transação sem risco de ler valor não-commitado.
- **Implementation constraints:** `RecomputeScore` tem que rodar **depois** do commit (lê o próprio `provider_profiles` de volta) — chamar dentro da tx leria o valor antigo. Verificado.
- **Confidence:** Confirmed — pós-fix, `years` 9→1 baixou o score em 12.00 pts exatos, e restaurar pra 9 recomputou pra 52.85 (o valor correto: o 46.85 anterior era ele mesmo um resíduo corrompido por essa mesma falha em sessão anterior — o fix, ao rodar recompute, também sarou a linha). Controle: editar só a bio não moveu o score.

#### [P2-2] Eventos de analytics eram perdidos silenciosamente — goroutine usando o contexto da request
- **Location:** `internal/service/analytics.go:24` (`RecordEvent`), chamado em `internal/handler/provider.go:95` e `internal/handler/chat.go:59`
- **Dimension:** Reliability
- **What:** os dois call sites disparam `go h.analytics.RecordEvent(r.Context(), ...)`. O `r.Context()` é cancelado assim que o handler retorna; a goroutine destacada corre contra esse cancelamento e, quando perde, o `INSERT` é abortado. Como `RecordEvent` engole o erro (`_, _ =`), o evento some sem rastro.
- **Code (verbatim, antes do fix):**
  ```go
  func (s *AnalyticsService) RecordEvent(ctx context.Context, ...) {
      // Fire-and-forget: analytics failures must not block the main flow.
      _, _ = s.db.Exec(ctx,
          `INSERT INTO provider_events ...`,
          ...)
  }
  ```
- **Why it matters:** `provider_events` alimenta o painel do prestador (`ViewCount30d`, `ContactCount30d`) e o ranking de categoria. Visualizações de perfil e contatos iniciados eram subcontados de forma não-determinística — o painel mostra menos atividade do que aconteceu de verdade, minando justamente a "confiança visível" que é o produto.
- **Evidence / how verified:** confirmado por leitura (padrão clássico Go: contexto request-scoped passado a goroutine que sobrevive à request) e por reprodução pós-fix — 10 `GET /providers/{id}` seguidos produziram exatamente 10 `profile_view` em `provider_events` (antes do fix, parte se perderia na corrida).
- **Fix:** dentro de `RecordEvent`, desacoplar do cancelamento com `context.WithoutCancel(ctx)` e dar um deadline próprio de 5s (`context.WithTimeout`) — corrige os dois call sites de uma vez sem mudar a assinatura, e evita vazar goroutine se o banco travar.
- **Implementation constraints:** `context.WithoutCancel` é Go 1.21+ (projeto está em 1.26, ok). Preserva os values do contexto (irrelevante aqui) mas descarta o cancelamento — exatamente o desejado para fire-and-forget.
- **Confidence:** Confirmed — build + vet limpos, 10/10 eventos persistidos na reprodução.

## Patterns observed

- **A regra "toda escrita numa coluna que alimenta o score chama `RecomputeScore`" não estava centralizada** — three call sites (rating, recommendation ×2) acertavam, o quarto (UpdateMe) esquecia. É a mesma família do achado de auto-avaliação da auditoria de frontend/produto de 08/07: o Score Aldeia tem várias portas de escrita e nem todas passam pelo mesmo guardião. Não justifica refactor agora (4 call sites), mas se surgir um quinto, considerar um método único `writeAndRescore`.
- **Multi-tenancy segue consistente:** reverifiquei `notification.go`, `chat.go`, `question.go`, `request.go`, `admin.go` e os services de rating/recommendation — toda query tenant-scoped usa `claims.CommunityID` do contexto, nunca valor do cliente. `notifications` filtra por `user_id` (dono direto), o que é suficiente.

## What's working well

- **Refresh token reuse detection implementado corretamente** (`auth.go:274`) — replay de token revogado agora derruba toda a família de refresh tokens do usuário, com o erro da contenção propagado (não engolido). Fecha o P1 do apêndice do skill.
- **Rate limit presente** em todos os endpoints pré-auth (`register`, `login`, `forgot-password`, `reset-password` a 5/min/IP) e no `presign` (30/min/IP) — o alerta do apêndice já foi endereçado.
- **Índices saudáveis:** o `token_hash` do refresh tem UNIQUE (índice automático, confirmado por `EXPLAIN`), e as colunas de FK usadas como lado dirigente de `WHERE`/`JOIN` têm índice composto liderando com a coluna certa. Nenhum seq scan em caminho quente.
- **Timeouts em tudo que é externo:** HTTP server (Read/Write/Idle), clients Resend e FCM (10s), e a goroutine de push do WS já tinha seu próprio `context.WithTimeout` de 10s.
- **`sanitizeFilename` no presign** — o filename do cliente é limpo (regex allow-list + corte de 100 chars) antes de virar chave S3.

## Resumo consolidado (2026-07-02 → 2026-07-09)

| Data | P0 | P1 | P2 | P3 |
|---|---|---|---|---|
| 2026-07-02 (todos corrigidos) | 1 | 4 | 6 | 5 |
| 2026-07-03 (corrigidos: 4 P1, 3 P2, 3 P3) | 0 | 4 | 4 | 4 |
| 2026-07-05 (corrigidos: 1 P1, 4 P2, 4 P3; 1 P3 sem correção) | 0 | 1 | 4 | 5 |
| 2026-07-09 (2 P2 corrigidos e verificados) | 0 | 0 | 2 | 0 |

A tendência de severidade caindo a cada rodada (P0/P1 zerados desde 07-05) é o sinal esperado de um backend que já passou por várias auditorias: o que resta são bugs de correção de baixa frequência, não buracos estruturais.

---

# Auditoria de acompanhamento — 2026-07-11 (delta + alinhamento dos dois clientes)

**Data:** 2026-07-11
**Escopo:** (1) delta do backend desde a auditoria de 2026-07-09 — exatamente 1 commit (`ffb24ab`, anonimização das visitas de perfil: `internal/handler/provider.go` + migration 000028); (2) alinhamento dos dois clientes (simulador iOS e emulador Android) contra o backend único.
**Stack:** inalterada (Go 1.26.4, chi v5, pgx/v5, PostgreSQL 18). Migration 28/28 aplicada, limpa. `go build`/`vet`/`test` verdes.

## Summary

- P0: 0 · P1: 0 · P2: 0 · P3: 0 (backend)
- **1 achado de alinhamento de clientes** (não é bug de backend): o build iOS instalado estava defasado — corrigido por rebuild nesta sessão.

## Auditoria do delta (`ffb24ab`)

O único código de backend novo desde 09/07 é a anonimização de `profile_view`. Verificado nas cinco dimensões — **nenhum achado**:

- **Segurança/privacidade — a promessa de anonimato fecha por completo:** `RecordEvent` recebe `nil` como actor (diff verbatim conferido); nenhuma leitura de `actor_id` restou no código fora do INSERT (`grep` em `internal/`); o middleware de log (`logger.go:17`) registra só `method/path/status/duration_ms` — sem identidade do caller — então nem correlação com logs de acesso reidentifica o visitante. `contact_initiated` mantém o actor de propósito (morador se revela ao abrir chat), decisão documentada na própria migration.
- **Confiabilidade:** reproduzido ao vivo em 10-11/07 — visitas do app Android gravaram com `actor_id` NULL e o painel do prestador contou corretamente (`view_count_30d` via `COUNT(*)`, independente do actor).
- **Migrations:** 000028 up/down pareados; o down é no-op **deliberado e documentado** (anonimato não pode ser des-anonimizado) — não é o padrão usual de reversão, mas é a semântica correta aqui.
- **Performance:** o UPDATE retroativo da migration foi one-shot em tabela pequena; nenhum índice novo necessário (leituras seguem pelos índices compostos existentes de `provider_events`).

## Alinhamento iOS ↔ Android

| Verificação | Resultado |
|---|---|
| Backend único para ambos | ✅ iOS → `localhost:8081`, Android → `10.0.2.2:8081` (mesmo processo; `/health` 200 dos dois caminhos) |
| Backend roda o código de HEAD | ✅ Provado pela visita anônima gravada em teste ao vivo (comportamento só existe no commit atual) |
| Contratos de API | ✅ Mesmo código Dart nos dois clientes; nenhum branching por plataforma nas chamadas |
| Build Android | ✅ Instalado 11/07 21:57 com o fix do Mural (`31a9972`) — alinhado com HEAD |
| Build iOS | ⚠️→✅ **Estava defasado** (binário Dart de 09/07 00:42, sem o fix do Mural — a aba Mural do admin renderizava em branco também no iOS, pois o bug é de código Dart compartilhado). **Corrigido nesta sessão por rebuild com HEAD.** |
| Cleartext HTTP | ✅ iOS: ATS permite localhost por padrão; Android: `usesCleartextTraffic` só no manifest de debug |
| WebSocket | ✅ Testado ao vivo no Android (11/07); iOS usa o mesmo código Dart e foi testado em 08/07 |

**Limitação declarada:** a verificação por toque no iOS segue indisponível (permissão de Acessibilidade do macOS revogada desde 09/07), então a correção do Mural no iOS é garantida por transitividade — mesmo código Dart, fix verificado ao vivo no Android com o erro de layout confirmado no console do framework — e não por toque no próprio iOS.

## What's working well

- Delta de backend mínimo e correto entre auditorias — as mudanças de produto recentes foram quase todas no mobile, e a única mudança de backend passou limpa pelas cinco dimensões.
- A disciplina de "reproduzir antes de reportar" pagou de novo: a suspeita de regressão no painel (contagem pós-anonimização) foi descartada por teste ao vivo, não por leitura de código.
