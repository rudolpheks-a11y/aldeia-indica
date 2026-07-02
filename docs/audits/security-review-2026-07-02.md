# Security Review — Fixes do Backend Audit (2026-07-02)

**Escopo:** revisão de segurança focada no diff não commitado que implementa os fixes descritos em `backend/BACKEND_AUDIT.md` — não é uma auditoria geral do código pré-existente, só das mudanças novas.

**Metodologia:** leitura completa do diff (`git diff`) com contexto adicional de cada arquivo tocado, checando cada mudança contra: SQL injection, bypass de autorização/IDOR, falhas de autenticação, TOCTOU, e regressão de middleware. Tentativa inicial de delegar a um sub-agente seguindo o skill `security-review` — a resposta veio corrompida por um erro de conexão e, ao ser retomado, o agente reconstruiu os achados antigos da auditoria em vez de analisar o diff; a revisão final abaixo foi feita manualmente, arquivo por arquivo.

## Resultado

**Nenhuma vulnerabilidade nova foi introduzida pelos fixes.**

| Arquivo | O que foi checado | Resultado |
|---|---|---|
| `internal/service/provider.go` | Queries `= ANY($1)` batalhadas (risco de SQL injection se mal parametrizadas) | ✅ `providerIDs []uuid.UUID` passado como parâmetro real do driver pgx, não interpolado em string |
| `internal/handler/request.go` | `INSERT ... SELECT ... WHERE community_id=$4` em `Respond`; filtros `AND community_id=` em `Get`/`ListResponses` | ✅ Parâmetros bindados corretamente, ordem de colunas confere, `RowsAffected()==0 → 404` fecha o caminho de bypass |
| `internal/handler/chat.go` | Lógica do `assertParticipant` (403 vs 404, operadores de comparação) | ✅ `userID != pA && userID != pB` correto; todo call site retorna imediatamente ao receber erro |
| `internal/service/chat.go` | `GetOrCreateConversation` — novo check de `ErrCrossCommunity` | ✅ Query parametrizada, comparação direta de UUID |
| `internal/ws/client.go` | Mesma checagem de participante no path WebSocket; reuso do `ListParticipants` já resolvido | ✅ Consistente com o lado REST, sem TOCTOU (participantes não mudam após criação da conversa) |
| `internal/service/auth.go` | Split do branch revoked/expired; revogação em massa por `user_id` no reuso | ✅ `rt.UserID` só é alcançável via um token que já existiu e foi emitido para aquele usuário — não é vetor pra derrubar sessão de terceiros arbitrários |
| `internal/server/router.go` | Se alguma rota perdeu middleware de auth/RBAC ao ser reorganizada | ✅ Todas as rotas seguem dentro do mesmo grupo `Authenticate`; `.With(rateLimit)` só adiciona, nunca remove |
| `internal/handler/provider.go` | Novo check `pathID != claims.UserID` em `AddPhoto` | ✅ Comparação direta, sem bypass |
| `internal/fcm/client.go`, `internal/email/resend.go` | Timeouts adicionados | ✅ Sem impacto de segurança, só reliability |
| `.github/workflows/backend.yml` | `pull_request_target`, secrets, input não confiável em `run:` | ✅ Trigger padrão (`push`/`pull_request`), sem `pull_request_target`, sem secrets, sem interpolação de dados do PR |
| `backend/migrations/000018_*.sql` | Conteúdo da migration | ✅ Só `CREATE INDEX`, sem impacto de segurança |
| `go.mod`/`go.sum` | Nova dependência `github.com/go-chi/httprate` | ✅ Pacote oficial da org go-chi |

## Achados corrigidos nesta rodada (referência)

Ver `backend/BACKEND_AUDIT.md` para o relatório completo com evidência file:line de cada achado original e a tabela de status. Resumo:

- **P0** Chat sem checagem de participante (leitura e escrita) — corrigido e verificado com curl entre identidades cruzadas.
- **P1** Service requests sem escopo de comunidade — corrigido e verificado.
- **P1** Refresh token sem detecção de reuso — corrigido e verificado (reuso derruba a família inteira de tokens).
- **P1** N+1 na busca de prestadores — corrigido, resultado idêntico ao anterior (comparação byte-a-byte).
- **P1** Timeouts ausentes em chamadas externas — corrigido.
- **P2** Índices faltantes, rate limiting, erros silenciados, rotas com `{id}` ignorado — corrigidos.
- **P3** Scaffolding sqlc morta, Dockerfile rodando como root, linha morta — corrigidos.
- Achado adicional descoberto durante a implementação: `GetOrCreateConversation` não validava se o outro usuário pertencia à mesma comunidade — corrigido junto com o fix do chat.

**Não corrigido (decisão explícita, não pendência):** refatoração de camadas dos handlers (`AdminHandler`/`CategoryHandler`/`RequestHandler` sem service layer) e infraestrutura de teste completa com banco — CI mínimo (build+vet+test) foi adicionado, mas testes automatizados contra banco real ficaram fora de escopo por decisão do product owner.
