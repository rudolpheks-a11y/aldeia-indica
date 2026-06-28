# Padrões de código

## Go

- Handlers são finos: validam input, delegam para service, serializam resposta.
- Services orquestram transações e regras de negócio.
- `jsonOK` e `jsonError` em `handler/auth.go` são helpers usados por todos os handlers.
- Sempre use transação (`tx`) quando múltiplas tabelas são afetadas no mesmo serviço.
- `community_id` sempre vem do JWT via `middleware.ClaimsFrom(ctx)` — nunca do body da requisição.

## Flutter

- Um `FutureProvider.family` por recurso que precisa de ID dinâmico.
- `ref.watch(apiClientProvider)` para acessar a API em qualquer provider.
- `LoadingOverlay` em telas com ação assíncrona.
- Tokens armazenados em `flutter_secure_storage` — nunca em SharedPreferences.
- Toda navegação interna usa `context.push` (go_router).
- `AppBackButton` em todas as telas secundárias.

## Pacotes Flutter relevantes

| Pacote | Versão | Uso |
|---|---|---|
| `google_fonts` | ^6.2.1 | Poppins (títulos) + Inter (corpo) |
| `flutter_svg` | ^2.0.16 | Logo SVG — não suporta `<svg>` aninhado, usar `<g transform>` |
| `url_launcher` | ^6.3.1 | Abre e-mail do administrador |

## Paleta de cores (`app_colors.dart`)

| Token | Hex | Uso |
|---|---|---|
| Primary | `#1B5E20` | Verde floresta |
| Secondary | `#F57F17` | Âmbar/laranja — "Indica" |
| Accent | `#FFB300` | Âmbar claro — estrelas, sol |
| Success | `#2E7D32` | — |
| Surface | `#F9FBF9` | Background |
