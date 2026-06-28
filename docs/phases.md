# Histórico de fases

## Fase 1 — Diretório de Confiança (concluída)

Auth, aprovação de moradores, perfis de prestadores, busca, avaliações, recomendações, pedidos de serviço, painel admin, Score Aldeia, upload S3 via presigned URL. Migrations 000001–000011.

## Fase 2 — Comunicação (concluída)

- WebSocket Hub por user_id (`internal/ws/`); cliente com coder/websocket (context-based)
- Chat REST + WS; FCM graceful no-op quando não configurado
- Bug fix: busca usava `DISTINCT ON` que impedia ordenação por score — substituído por `EXISTS` subquery
- Bug fix: `TokenPair` inclui `user_id` para Flutter determinar `is_mine` nas mensagens
- Flutter: botão "Contatar" cria conversa e navega para `/chat/:id`
- Migration 000016: `messages` ganha `media_key`, `lat`, `lng`

## Fase 3 — Analytics e Multi-comunidade (concluída)

- `internal/service/analytics.go` — RecordEvent, DashboardSummary (30d), HireCompleted
- Tracking automático: `profile_view`, `contact_initiated`
- `POST /providers/:id/hire` — confirma contratação e recalcula Score
- `POST /admin/communities`, `GET /communities` — multi-comunidade
- Migration 000012 — índices de analytics
- Flutter: dashboard com dados reais, ranking de categoria, Score badge colorido
- Flutter: tela admin com tabs Usuários / Documentos / Comunidades

## Fase 4 — Perfil do Prestador (concluída)

- Recuperação de senha: código 6 dígitos por e-mail via Resend API (migration 000013)
- Habilidades: 17 categorias com checkboxes + campo de busca em tempo real
- Transporte: toggle público/combustível em `provider_profiles` (migration 000014)
- Anúncio: textarea de bio profissional; patch-style PUT
- Agenda: toggle por dia + time pickers início/fim; `provider_availability` (migration 000015)
- Home do prestador: 3 tiles — Habilidades, Anúncio, Agenda
- ProfileScreen: seção Disponibilidade com chips coloridos visível para moradores
- Tela inicial diferenciada por role (extraído do JWT)
- WebSocket: fix Hijacker + filtro de tipo de mensagem

## Próximos passos

- Prestadores `is_visible=false` — tela de status pendente no home do prestador
- Busca textual no backend (param `q` em `GET /providers`)
- Notificações push (FCM configurado mas sem `FCM_SERVICE_ACCOUNT_JSON`)
