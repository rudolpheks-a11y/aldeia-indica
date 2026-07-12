# Ciclo de vida da conta — do cadastro à desativação

**Atualizado:** 2026-07-12 · **Commit:** `900c8b6`

Como uma conta nasce, o que o sistema registra sobre ela, como ela entra, e o que
acontece quando ela é desativada. Vale para morador, prestador e admin.

---

## 1. Cadastro

### Morador (`POST /auth/register/morador`)

O morador escolhe a comunidade, o condomínio, e informa nome, e-mail, senha e endereço.
Dois campos de **código de convite** são opcionais no formulário — mas decidem tudo:

| Convites | Status inicial | O que acontece |
|---|---|---|
| **2 códigos, de 2 moradores diferentes** | `active` | Entra direto. `verified_resident = true`. Os convites são consumidos (`used_at`). |
| **Nenhum código** | `pending` | Não consegue logar. Fica esperando o admin aprovar manualmente. |
| **Só 1 código** | — | Rejeitado (400): ou manda os dois, ou nenhum. |

Os dois códigos precisam vir de **moradores diferentes** (senão 400) e são travados com
`FOR UPDATE` durante a transação — se dois cadastros tentarem consumir o mesmo código ao
mesmo tempo, o segundo espera e falha, em vez de ambos passarem.

É esse par de convites que mantém a rede fechada: quem entra sem indicação de dois
vizinhos depende de um ato explícito do admin.

### Prestador (`POST /auth/register/prestador`)

O prestador informa nome, e-mail, senha, cidade, anos no bairro e as categorias que
atende. **Não precisa de convite** — nasce `active` e `is_visible = true`, ou seja,
aparece na busca imediatamente.

Uma coisa é obrigatória: o **aceite de avaliações públicas**. O botão "Cadastrar" fica
desabilitado até o checkbox ser marcado, e o backend recusa o cadastro (400) se o aceite
não vier. O instante do cadastro é gravado como o instante do aceite
(`provider_profiles.ratings_acknowledged_at`), e o admin vê essa data no painel.

Prestadores cadastrados antes de 12/07/2026 têm esse campo nulo — é histórico, não
irregularidade.

### E-mail duplicado

O e-mail é único **por comunidade** (`UNIQUE(community_id, email)`). Tentar cadastrar um
e-mail já usado retorna **409**. Se o e-mail pertencer a uma conta **excluída**, o 409 vem
com `code: email_taken_deleted` e uma mensagem diferente — mandando reativar a conta
antiga (ver seção 5).

---

## 2. O que o sistema registra

### No cadastro

| Tabela | Guarda |
|---|---|
| `users` | e-mail, hash bcrypt da senha, papel, status, nome, comunidade |
| `morador_profiles` | endereço, número, quadra, `verified_resident` |
| `provider_profiles` | cidade, anos no bairro, bio, visibilidade, aceite das avaliações, e os contadores de reputação (`score_aldeia`, `avg_rating`, `recommendation_count`) |

A senha **nunca** é armazenada em texto — só o hash bcrypt.

### Durante o uso

O prestador constrói o próprio perfil em três telas independentes, e cada uma salva só a
sua fatia (o `PUT /providers/me` é patch-style, então salvar a agenda não apaga a bio):

- **Habilidades** → `provider_services` (as categorias em que ele aparece na busca)
- **Anúncio** → `provider_profiles.professional_bio`
- **Agenda** → `provider_availability` (dia da semana + intervalos; vários por dia)

O morador gera o resto do dado social:

- **Avaliação** (`ratings`) — 4 critérios, assinada e pública
- **Indicação** (`recommendations`) — nota única, **anônima** para o prestador
- **Pedido de serviço** (`service_requests`) + respostas dos prestadores
- **Favoritos**, **perguntas públicas**, **avisos no mural** (que passam por moderação do admin)

Avaliações e indicações alimentam o **Score Aldeia** e os selos. É esse histórico que
torna a exclusão de conta um problema delicado — ver seção 5.

---

## 3. Login

`POST /auth/login` com comunidade + e-mail + senha. O backend confere o hash bcrypt e,
**só então**, avalia o estado da conta (para não revelar nada a quem não sabe a senha):

| Estado da conta | Resposta |
|---|---|
| Ativa | **200** + par de tokens |
| Senha errada / e-mail inexistente | **401** (mesma resposta para os dois — não vaza quais e-mails existem) |
| `pending` (morador sem os 2 convites) | **403** — tela "aguardando aprovação" |
| `suspended` | **403** |
| **Excluída pelo próprio dono** | **403** + `code: account_deleted` → o app oferece **reativar** |
| **Excluída pelo admin** | **403** + `code: account_deleted_by_admin` → não reativa |

O login é limitado a **5 tentativas por minuto por IP**.

### Sessão

- **Access token:** JWT HS256, **15 minutos**, com `{user_id, community_id, role}`. É de onde
  o app tira o papel para decidir qual home mostrar.
- **Refresh token:** 48 bytes aleatórios, guardado como **SHA-256** (o valor cru nunca fica
  no banco), **rotacionado a cada uso**.

Todo dado de negócio é filtrado por `community_id`, extraído do token — nunca de um campo
enviado pelo cliente.

### Esqueci a senha

`POST /auth/forgot-password` envia um código de 6 dígitos por e-mail (Resend), válido por
15 minutos, com rate limit. `POST /auth/reset-password` troca a senha.

---

## 4. Desativação — o que muda no banco

Duas portas levam ao mesmo lugar:

- **O próprio usuário:** menu ⋮ na home → "Excluir conta" → `DELETE /users/me`
- **O admin:** aba Usuários → ícone de lixeira → `DELETE /admin/users/:id`

O admin **não** exclui outro admin nem a si mesmo (403) — ficar sem moderador não é uma
opção, e ele não teria como se reativar.

### O que realmente acontece

**Nada é apagado. Nada é anonimizado.** A conta recebe:

- `deleted_at = now()`
- `deleted_by = quem excluiu` (o próprio usuário, ou o admin)
- todos os refresh tokens revogados — a sessão morre na hora, sem esperar o token expirar

Nome, e-mail, senha, perfil, avaliações e mensagens continuam exatamente onde estavam.

### Por que não apagar de verdade

**Razão técnica:** a maioria das chaves estrangeiras para `users(id)` é RESTRICT
(`ratings`, `recommendations`, `messages`, `service_requests`, `provider_questions`). O
Postgres simplesmente **bloquearia** o `DELETE`.

**Razão de produto (mais importante):** um `ON DELETE CASCADE` apagaria as avaliações e
indicações que a pessoa **deu a outros**. O Score Aldeia de quem ficou mudaria por causa
da saída de um terceiro. A reputação da rede não pode depender de quem permanece nela.

### Por que não anonimizar o e-mail

Porque é isso que fecha a fraude. Se o e-mail fosse liberado, um prestador com avaliação
ruim poderia excluir a conta e se recadastrar com o mesmo e-mail, nascendo limpo. O
e-mail continua **preso à conta excluída**: o recadastro é bloqueado com 409, e a única
saída é reativar a conta antiga — que volta com o histórico junto.

---

## 5. Depois da desativação

### Some da rede, na hora

Todo caminho de leitura filtra `deleted_at IS NULL`: login, busca de prestadores,
destaques, perfil por id, favoritos de quem o tinha salvo, listagem de usuários do admin
e as contagens da Visão Geral.

### O que sobrevive

As avaliações e indicações que a pessoa **deu** continuam valendo — o Score Aldeia de
quem ficou não se mexe. As avaliações que ela **recebeu** também ficam, presas à conta:
é o que ela reencontra se voltar.

### Reativação — e quem tem direito a ela

É aqui que `deleted_by` decide tudo:

| Quem excluiu | O dono pode reativar? | Como |
|---|---|---|
| **O próprio usuário** | **Sim** | Faz login com a senha antiga → o app oferece "Reativar conta" → `POST /auth/reactivate`. Volta com perfil e histórico intactos. |
| **O admin** | **Não** | Login e reativação devolvem 403. Só falando com o administrador. |

Sem essa distinção, banir um fraudador não valeria de nada: bastaria ele logar de novo e
se reativar. A senha antiga é a prova de posse — ninguém reativa a conta de outro.

### O admin enxerga tudo

A aba **"Excluídos"** do painel (`GET /admin/users?deleted=true`) lista todas as contas
desativadas, com a data e um selo dizendo se foi **o próprio usuário** ou **o admin**.
É a trilha antifraude: um prestador sumindo logo depois de uma avaliação ruim fica
visível.

---

## 6. Estados possíveis de uma conta

```
                    cadastro
                        │
      ┌─────────────────┴─────────────────┐
      │ morador sem convites              │ morador com 2 convites
      │                                   │ prestador (sempre)
      ▼                                   ▼
  ┌─────────┐   admin aprova         ┌────────┐
  │ pending │ ─────────────────────► │ active │ ◄──┐
  └─────────┘                        └────────┘    │
                                      │      │     │ POST /auth/reactivate
                        DELETE /users/me    DELETE /admin/users/:id
                                      │      │     │ (só se deleted_by = o próprio)
                                      ▼      ▼     │
                            ┌──────────────────────┴─┐
                            │  deleted_at != NULL     │
                            │  deleted_by = usuário   │──► pode voltar
                            │  deleted_by = admin     │──► não pode voltar
                            └─────────────────────────┘
```

O e-mail permanece ocupado em **todos** os estados, inclusive excluída.

---

## 7. Tensão conhecida (LGPD)

"Excluir conta" aqui significa **desativar**, não apagar dados pessoais: nome, e-mail e
endereço permanecem no banco. A escolha foi deliberada e prioriza a integridade da rede
de confiança sobre o direito ao esquecimento.

Se um dia for preciso atender a um pedido formal de eliminação de dados, será um fluxo
separado — e provavelmente manual, no banco, aceitando o impacto no Score Aldeia de
terceiros. Vale rever essa decisão antes de qualquer lançamento público mais amplo.
