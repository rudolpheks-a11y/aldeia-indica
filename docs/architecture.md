# Arquitetura

## Backend

### Camadas

```
handler → service → repository (gerado por sqlc) → PostgreSQL
               ↓
           domain/     ← tipos puros, sem imports externos
```

- `internal/domain/` — structs e regras puras. `score.go` contém a fórmula do Score Aldeia.
- `internal/service/` — lógica de negócio, orquestra repositórios e transações.
- `internal/handler/` — HTTP handlers finos: validam input, delegam, serializam.
- `internal/server/middleware/` — JWT auth, community scope, RBAC, logger.
- `internal/repository/queries/` — arquivos `.sql` que o sqlc transforma em Go.

### WebSocket

- `internal/ws/hub.go` — Hub registrado por user_id (não por conversa); suporta múltiplas conexões simultâneas.
- `internal/ws/client.go` — loop de read/write com coder/websocket (context-based, não gorilla).
- `internal/ws/handler.go` — upgrade HTTP com auth via `?token=` query param.
- `internal/fcm/client.go` — FCM HTTP v1 API com oauth2/google; graceful no-op se `FCM_SERVICE_ACCOUNT_JSON` não configurado.

### Analytics

- `internal/service/analytics.go` — `RecordEvent` (fire-and-forget), `DashboardSummary` (30d stats + rank na categoria), `HireCompleted`.
- Tracking automático: `profile_view` ao `GET /providers/:id`, `contact_initiated` ao criar conversa.

## Flutter

### Estrutura de features

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

### Providers globais (`auth_provider.dart`)

```dart
storageServiceProvider  // flutter_secure_storage — tokens JWT
apiClientProvider       // Dio com interceptor de token + refresh automático
authRepositoryProvider  // login/register/logout
authProvider            // AsyncNotifierProvider<AuthNotifier, AuthState>
```

### Roteamento

`go_router` em `core/router/app_router.dart`. Redirect automático por `authProvider`:
- `AuthAuthenticated` → `/home` (branch por role via JWT)
- `AuthPending` → `/pending-approval`
- `AuthUnauthenticated` → `/login`

Role extraído do JWT (campo `role` no payload), salvo em `flutter_secure_storage`, lido em `AuthAuthenticated`.

### WebSocket no Flutter

`WsService` em `core/services/ws_service.dart` — gerencia conexão, reconexão automática em 3s. Usado pelo `ChatNotifier` via `wsServiceProvider`.

### Decisões técnicas

- `PUT /providers/me` é patch-style: usa `COALESCE` para escalares; `category_slugs` só reescreve quando não é nil — cada tela salva seu slice sem destruir o outro.
- `registerPrestador` no repo NÃO salva tokens — morador continua logado após cadastrar alguém.
- Busca textual de prestadores é client-side — backend `/providers` não tem param `q` ainda.
- Nota única ("Recomende") aplica o mesmo valor aos 4 critérios do backend.
