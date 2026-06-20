# Aldeia Indica — CLAUDE.md

Rede de confiança comunitária para moradores e prestadores de serviços em bairros residenciais (Aldeia da Serra e similares).

## Stack

| Camada | Tecnologia |
|---|---|
| Backend API | Go 1.26.4 |
| Mobile | Flutter 3.44.2 (iOS + Android) |
| Banco de dados | PostgreSQL 18.4 |
| Storage de mídia | AWS S3 / MinIO (dev local) |
| Push notifications | Firebase Cloud Messaging |
| HTTP Router | chi v5 |
| WebSocket | coder/websocket |
| Driver PostgreSQL | pgx/v5 |
| State management (Flutter) | Riverpod ^2.6 |
| Roteamento (Flutter) | go_router ^14 |
| HTTP client (Flutter) | Dio ^5.8 |

## Estrutura do repositório

```
aldeia-indica/
├── backend/          # API Go
├── mobile/           # App Flutter
├── docker-compose.yml
└── CLAUDE.md
```

## Comandos essenciais

### Backend

Trabalhar sempre de dentro de `backend/`:

```bash
# Rodar em dev
make run

# Buildar
make build          # gera bin/api

# Testes
make test           # go test -race ./...

# Migrations
make migrate-up     # requer DATABASE_URL no env
make migrate-down   # reverte 1 migration

# Gerar queries sqlc
make generate
```

### Mobile (Flutter)

Flutter SDK em `~/development/flutter/bin/` — adicione ao PATH:
```bash
export PATH="$PATH:$HOME/development/flutter/bin"
```

```bash
cd mobile/
flutter pub get
flutter run             # requer emulador ou dispositivo conectado
flutter test
flutter build apk       # Android
flutter build ios       # iOS (requer Xcode)
```

### Docker (ambiente completo local)

```bash
# Subir PostgreSQL 18 + MinIO + backend
docker compose up

# Só o banco e storage (backend rodando fora do Docker)
docker compose up postgres minio
```

## Configuração de ambiente (backend)

Copie `.env.example` para `.env.local` e preencha:

```
DATABASE_URL=postgres://aldeia:secret@localhost:5432/aldeia_indica?sslmode=disable
JWT_SECRET=<mínimo 32 bytes aleatórios>
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=720h
PORT=8080

# S3 / MinIO local
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin
AWS_BUCKET_PUBLIC=aldeia-public
AWS_BUCKET_PRIVATE=aldeia-private
AWS_ENDPOINT=http://localhost:9000

CLOUDFRONT_BASE_URL=http://localhost:9000/aldeia-public
FCM_SERVICE_ACCOUNT_JSON=   # base64 do JSON do Firebase Admin
```

Para produção: remova `AWS_ENDPOINT`, configure credenciais AWS reais e Firebase.

## Arquitetura do backend

### Camadas (em ordem de dependência)

```
handler → service → repository (gerado por sqlc) → PostgreSQL
               ↓
           domain/     ← tipos puros, sem imports externos
```

- `internal/domain/` — structs e regras puras (sem DB, sem HTTP). `score.go` contém a fórmula do Score Aldeia.
- `internal/service/` — lógica de negócio, orquestra repositórios.
- `internal/handler/` — HTTP handlers finos, delegam para service.
- `internal/server/middleware/` — JWT auth, community scope, RBAC, logger.
- `internal/repository/queries/` — arquivos `.sql` que o sqlc transforma em Go.

### Multi-tenancy

**Toda** query de negócio filtra por `community_id`. O middleware `internal/server/middleware/auth.go` extrai `community_id` do JWT e injeta no contexto. Nunca derive community_id de outra fonte.

### Auth

- Access token: JWT HS256, 15 min. Claims: `{uid, cid, role}`.
- Refresh token: 64 bytes aleatórios, armazenado como SHA-256 no banco (`refresh_tokens.token_hash`). Rotação a cada uso (antigo revogado).
- Middleware `Authenticate` → injeta `*domain.Claims` no contexto. Use `middleware.ClaimsFrom(ctx)` nos handlers.

### Score Aldeia

Fórmula em `internal/domain/score.go`:

```
score = (avg_rating/5 × 35) + (min(anos/10, 1) × 15) +
        (min(clientes/50, 1) × 20) + (min(contratações/100, 1) × 15) +
        (min(indicações/20, 1) × 15)
```

Recalculado na mesma transação após: inserção de rating, inserção/remoção de recommendation. Persistido em `provider_profiles.score_aldeia`. Sem cron.

### Upload de arquivos

Fluxo presigned URL — o servidor nunca faz proxy de binários:
1. Cliente chama `POST /api/v1/uploads/presign` com `{object_type, filename}`
2. API devolve `{upload_url, object_key}` (URL S3 válida por 15 min)
3. Cliente faz `PUT upload_url` diretamente com o arquivo
4. Cliente salva `object_key` no recurso (ex: `PUT /providers/me` com `{s3_key}`)

Documentos privados (CPF, RG) → bucket `AWS_BUCKET_PRIVATE`. Tudo mais → `AWS_BUCKET_PUBLIC`.

## Banco de dados

### Migrations

Numeradas sequencialmente em `backend/migrations/`. Rodar sempre via `make migrate-up`.

| Migration | Conteúdo |
|---|---|
| 000001 | communities |
| 000002 | users, morador_profiles, refresh_tokens, device_tokens |
| 000003 | user_approvals, approval_votes, invites |
| 000004 | provider_profiles, provider_photos |
| 000005 | service_categories, provider_services |
| 000006 | ratings |
| 000007 | recommendations |
| 000008 | conversations, messages |
| 000009 | service_requests, service_request_responses |
| 000010 | provider_events |
| 000011 | seed das 17 categorias |

### Regras importantes

- `users.status`: `pending` → `active` → `suspended`. Moradores precisam de aprovação para virar `active`.
- `provider_profiles.is_visible = false` até admin aprovar documentos (`doc_status = 'approved'`).
- `conversations`: `CHECK (participant_a < participant_b)` para garantir par canônico e evitar duplicatas.
- Ratings: `UNIQUE(community_id, provider_id, rater_id)` — um morador avalia um prestador uma vez.
- Recommendations: `UNIQUE(community_id, provider_id, recommender_id)` — idem.

## API endpoints

Base: `GET /api/v1/...` | Auth: `Authorization: Bearer <access_token>`

| Grupo | Endpoints principais |
|---|---|
| Auth | `POST /auth/register/morador`, `/auth/register/prestador`, `/auth/login`, `/auth/refresh`, `/auth/logout` |
| Aprovação | `GET /approvals/pending`, `POST /approvals/:id/vote`, `POST /approvals/:id/resolve` |
| Convites | `POST /invites`, `GET /invites/:token`, `POST /invites/:token/use` |
| Prestadores | `GET /providers` (search), `GET /providers/:id`, `PUT /providers/me`, `POST /providers/:id/photos` |
| Categorias | `GET /categories` (público) |
| Avaliações | `POST /ratings`, `GET /ratings/provider/:id` |
| Recomendações | `POST /recommendations`, `DELETE /recommendations/:id`, `GET /recommendations/provider/:id` |
| Pedidos | `GET /requests`, `POST /requests`, `POST /requests/:id/responses` |
| Chat | `GET /chat/conversations`, `GET /chat/conversations/:id/messages`, `WS /ws/chat?token=<jwt>` |
| Upload | `POST /uploads/presign` |
| Dashboard | `GET /dashboard/summary` |
| Admin | `GET /admin/users`, `PUT /admin/users/:id/status`, `GET /admin/documents`, `POST /admin/documents/:id/review` |

### Protocolo WebSocket (`/ws/chat?token=<jwt>`)

```json
// Enviar texto
{"type":"message","conversation_id":"<uuid>","body":"<texto>"}

// Enviar imagem (após upload presign)
{"type":"message","conversation_id":"<uuid>","media_key":"<s3key>"}

// Enviar localização
{"type":"location","conversation_id":"<uuid>","lat":-23.5,"lng":-46.8}

// Receber
{"type":"message","id":"<uuid>","sender_id":"<uuid>","body":"...","created_at":"..."}
{"type":"read","conversation_id":"<uuid>","reader_id":"<uuid>"}
```

## Arquitetura Flutter

### Estrutura de features

Cada feature segue:
```
features/<nome>/
  data/
    <nome>_repository.dart   # chamadas à API
    models/                  # DTOs com .fromJson()
  providers/
    <nome>_provider.dart     # Riverpod AsyncNotifier/FutureProvider
  presentation/
    <nome>_screen.dart
```

### Providers globais (em `auth_provider.dart`)

```dart
storageServiceProvider  // flutter_secure_storage (tokens JWT)
apiClientProvider       // Dio com interceptor de token + refresh automático
authRepositoryProvider  // login/register/logout
authProvider            // AsyncNotifierProvider<AuthNotifier, AuthState>
```

### Roteamento

`go_router` em `core/router/app_router.dart`. Redirect automático baseado no `authProvider`:
- `AuthAuthenticated` → `/search`
- `AuthPending` → `/pending-approval`
- `AuthUnauthenticated` → `/login`

### WebSocket no Flutter

`WsService` em `core/services/ws_service.dart` — gerencia conexão, reconexão automática em 3s. Usado pelo `ChatNotifier` via `wsServiceProvider`.

## Fases do projeto

### Fase 1 — Diretório de Confiança (concluída)
Auth, aprovação, perfis, busca, avaliações, recomendações, pedidos, admin, Score Aldeia, upload S3.

### Fase 2 — Comunicação (concluída)
- `internal/ws/hub.go` — Hub registrado por user_id (não por conversa); suporta múltiplas conexões simultâneas
- `internal/ws/client.go` — loop de read/write com coder/websocket (context-based, não gorilla)
- `internal/ws/handler.go` — upgrade HTTP com auth via `?token=` query param (WebSocket não suporta headers)
- `internal/service/chat.go` — GetOrCreateConversation, ListConversations, LoadHistory, PersistMessage, MarkRead
- `internal/handler/chat.go` — REST: POST /chat/conversations, GET /chat/conversations, GET /chat/conversations/:id/messages, POST /chat/conversations/:id/read
- `internal/fcm/client.go` — FCM HTTP v1 API com oauth2/google; graceful no-op se FCM_SERVICE_ACCOUNT_JSON não configurado
- Bug fix: busca de prestadores usava DISTINCT ON que impedia ordenação por score/rating — substituído por EXISTS subquery
- Bug fix: TokenPair agora inclui `user_id` para o Flutter determinar `is_mine` nas mensagens
- Flutter: botão "Contatar" no perfil cria conversa e navega para `/chat/:id`
- Flutter: `chat_provider.dart` adiciona `is_mine` a cada mensagem com base no user_id salvo

### Fase 3 — Analytics e Multi-comunidade (próxima)
- Dashboard completo do prestador (views, contatos, ranking por categoria)
- Score Aldeia em destaque na busca (badge colorido no card)
- Evento `hire_completed` → incrementa `total_hires` → recalcula Score
- Admin cria novas comunidades via API
- Otimização de queries (índices adicionais, query plans)

## Padrões de código

### Go
- Handlers são finos: validam input, delegam para service, serializam resposta.
- Services orquestram transações e regras de negócio.
- `jsonOK` e `jsonError` em `handler/auth.go` são helpers usados por todos os handlers.
- Sempre use transação (`tx`) quando múltiplas tabelas são afetadas no mesmo serviço.
- `community_id` sempre vem do JWT (via `middleware.ClaimsFrom(ctx)`), nunca do body da requisição.

### Flutter
- Um `FutureProvider.family` por recurso que precisa de ID dinâmico.
- `ref.watch(apiClientProvider)` para acessar a API em qualquer provider.
- `LoadingOverlay` em telas com ação assíncrona.
- Tokens armazenados em `flutter_secure_storage` — nunca em SharedPreferences.

## Infraestrutura local

```
localhost:8080  → Backend Go
localhost:5432  → PostgreSQL 18
localhost:9000  → MinIO (API S3)
localhost:9001  → MinIO Console (admin)
```

### Primeiro setup

```bash
# 1. Subir banco e storage
docker compose up postgres minio -d

# 2. Rodar migrations
cd backend
cp .env.example .env.local
# editar .env.local com as vars
source .env.local
make migrate-up

# 3. Rodar o servidor
make run

# 4. Testar
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/categories
```

## GitHub

Repositório: https://github.com/rudolpheks-a11y/aldeia-indica
