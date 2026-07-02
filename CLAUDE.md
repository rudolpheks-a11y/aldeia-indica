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
├── docs/             # Documentação auxiliar
├── docker-compose.yml
└── CLAUDE.md
```

## Comandos essenciais

```bash
# Backend (dentro de backend/)
make run            # sobe o servidor
make migrate-up     # aplica migrations (requer DATABASE_URL no env)
make migrate-down   # reverte 1 migration

# Docker
docker compose up postgres minio -d   # banco + storage em background

# Mobile — comando completo com flags obrigatórias
~/development/flutter/bin/flutter run \
  --dart-define API_BASE_URL=http://localhost:8081/api/v1 \
  --dart-define WS_BASE_URL=ws://localhost:8081 \
  -d "iPhone 17"
```

## Arquitetura do backend

```
handler → service (SQL direto via pgx/v5) → PostgreSQL
               ↓
           domain/     ← tipos puros, sem imports externos
```

**Multi-tenancy:** toda query de negócio filtra por `community_id`. Extraído do JWT pelo middleware `internal/server/middleware/auth.go` e injetado no contexto. Nunca derive `community_id` de outra fonte.

**Auth:** access token JWT HS256, 15 min, claims `{uid, cid, role}`. Refresh token: 64 bytes aleatórios, armazenado como SHA-256 em `refresh_tokens.token_hash`, rotacionado a cada uso. Use `middleware.ClaimsFrom(ctx)` nos handlers.

Ver [docs/architecture.md](docs/architecture.md) para camadas detalhadas, WebSocket, analytics e arquitetura Flutter.

## Infraestrutura local

```
localhost:8081  → Backend Go  ← OrbStack ocupa 8080 permanentemente; .env.dev força 8081
localhost:5432  → PostgreSQL 18
localhost:9000  → MinIO (API S3)
localhost:9001  → MinIO Console
```

**Startup dev:** abrir OrbStack → `docker compose up postgres minio -d` → `cd backend && set -a && . ./.env.dev && set +a && go run ./cmd/api/main.go`

## GitHub

Repositório: https://github.com/rudolpheks-a11y/aldeia-indica

## Docs

- [docs/api.md](docs/api.md) — Endpoints REST completos + protocolo WebSocket
- [docs/database.md](docs/database.md) — Tabela de migrations (000001–000016) + regras do schema + fórmula Score Aldeia
- [docs/architecture.md](docs/architecture.md) — Camadas backend, WebSocket, analytics, arquitetura Flutter, decisões técnicas
- [docs/conventions.md](docs/conventions.md) — Padrões de código Go e Flutter, paleta de cores, pacotes relevantes
- [docs/phases.md](docs/phases.md) — Histórico de fases (1–4) e próximos passos
- [docs/setup.md](docs/setup.md) — Variáveis de ambiente, primeiro setup, comandos Flutter completos, usuários de teste
- [docs/audits/](docs/audits/) — Relatórios pontuais de auditoria/security review (não são referência permanente)
