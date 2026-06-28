# API Reference

Base: `/api/v1/...` | Auth: `Authorization: Bearer <access_token>`

## Endpoints

| Grupo | Endpoints |
|---|---|
| Auth | `POST /auth/register/morador`, `POST /auth/register/prestador`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `POST /auth/forgot-password`, `POST /auth/reset-password` |
| Aprovação | `GET /approvals/pending`, `POST /approvals/:id/vote`, `POST /approvals/:id/resolve` |
| Convites | `POST /invites`, `GET /invites/:token`, `POST /invites/:token/use` |
| Prestadores | `GET /providers` (search), `GET /providers/me`, `GET /providers/:id`, `PUT /providers/me`, `PUT /providers/me/availability`, `POST /providers/:id/photos`, `DELETE /providers/:id/photos/:photoID`, `POST /providers/:id/hire` |
| Categorias | `GET /categories` (público) |
| Avaliações | `POST /ratings`, `GET /ratings/provider/:id` |
| Recomendações | `POST /recommendations`, `DELETE /recommendations/:id`, `GET /recommendations/provider/:id` |
| Pedidos | `GET /requests`, `POST /requests`, `GET /requests/:id`, `PUT /requests/:id`, `POST /requests/:id/responses`, `GET /requests/:id/responses` |
| Chat | `POST /chat/conversations`, `GET /chat/conversations`, `GET /chat/conversations/:id/messages`, `POST /chat/conversations/:id/read` |
| Upload | `POST /uploads/presign` |
| Dashboard | `GET /dashboard/summary` |
| Comunidades | `GET /communities` (público) |
| Admin | `GET /admin/users`, `PUT /admin/users/:id/status`, `GET /admin/documents`, `POST /admin/documents/:providerID/review`, `POST /admin/communities` |

## WebSocket (`/ws/chat?token=<jwt>`)

Auth via query param — WebSocket não suporta headers customizados.

```json
// Enviar texto
{"type":"message","conversation_id":"<uuid>","body":"<texto>"}

// Enviar imagem (após upload presign)
{"type":"message","conversation_id":"<uuid>","media_key":"<s3key>"}

// Enviar localização
{"type":"location","conversation_id":"<uuid>","lat":-23.5,"lng":-46.8}

// Receber mensagem
{"type":"message","id":"<uuid>","sender_id":"<uuid>","body":"...","created_at":"..."}

// Receber confirmação de leitura
{"type":"read","conversation_id":"<uuid>","reader_id":"<uuid>"}
```

## Upload (presigned URL)

Servidor nunca faz proxy de binários:
1. `POST /uploads/presign` com `{object_type, filename}` → retorna `{upload_url, object_key}` (válida 15 min)
2. Cliente faz `PUT upload_url` diretamente com o arquivo binário
3. Cliente salva `object_key` no recurso (ex: `PUT /providers/me` com `{s3_key}`)

Documentos privados (CPF, RG) → `AWS_BUCKET_PRIVATE`. Demais → `AWS_BUCKET_PUBLIC`.
