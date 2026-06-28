# Setup e configuração

## Configuração de ambiente (backend)

Copie `.env.example` para `.env.dev` (dev local) ou `.env.local` e preencha:

```
DATABASE_URL=postgres://aldeia:secret@localhost:5432/aldeia_indica?sslmode=disable
JWT_SECRET=<mínimo 32 bytes aleatórios>
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=720h
PORT=8081                   # 8080 é ocupado permanentemente pelo OrbStack

# S3 / MinIO local
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin
AWS_BUCKET_PUBLIC=aldeia-public
AWS_BUCKET_PRIVATE=aldeia-private
AWS_ENDPOINT=http://localhost:9000

CLOUDFRONT_BASE_URL=http://localhost:9000/aldeia-public
FCM_SERVICE_ACCOUNT_JSON=   # base64 do JSON do Firebase Admin
RESEND_API_KEY=             # API key do Resend (e-mails de recuperação de senha)
```

Para produção: remova `AWS_ENDPOINT`, configure credenciais AWS reais e Firebase.

## Primeiro setup

```bash
# 1. Subir banco e storage
docker compose up postgres minio -d

# 2. Rodar migrations
cd backend
cp .env.example .env.dev
# editar .env.dev com as vars acima
set -a && . ./.env.dev && set +a
make migrate-up

# 3. Rodar o servidor
go run ./cmd/api/main.go

# 4. Testar
curl http://localhost:8081/health
curl http://localhost:8081/api/v1/categories
```

## Comandos Flutter completos

Flutter SDK em `~/development/flutter/bin/`:

```bash
export PATH="$PATH:$HOME/development/flutter/bin"
cd mobile/

# Dev (simulator iPhone 17)
flutter run \
  --dart-define API_BASE_URL=http://localhost:8081/api/v1 \
  --dart-define WS_BASE_URL=ws://localhost:8081 \
  -d "iPhone 17"

# Outros
flutter pub get
flutter test
flutter build apk       # Android
flutter build ios       # iOS (requer Xcode)
```

Simulator: iPhone 17, UUID `AB85E5AB-4F6A-411F-BA06-E8FFE3A8B88E`

## Usuários de teste

| E-mail | Senha | Role | Notas |
|---|---|---|---|
| `rudolpheks@hotmail.com` | — | morador | comunidade Aldeia da Serra |
| `prestador@teste.com` | `123456` | prestador | `is_active=true`, `is_visible=false` (aguarda aprovação de docs) |
