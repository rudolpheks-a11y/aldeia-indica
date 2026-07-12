# Inventário de botões do app — por papel

**Data:** 2026-07-12 · **Commit:** `c78f9e0` · **Fonte:** leitura de `mobile/lib/` (26 rotas, 25 telas)

Este documento lista **todo elemento interativo** do app Flutter — não só `ElevatedButton`,
mas também tiles tocáveis, ícones da AppBar, checkboxes, switches, chips e itens de lista com
`onTap`. Cada entrada traz o que o botão faz e por que ele existe.

A divisão é por **papel que enxerga o botão em runtime**, não por arquivo. Várias telas são
compartilhadas e mostram botões diferentes conforme o papel (`role`), a posse do recurso
(`isOwner`) ou a auto-visualização (`isSelf`) — quem determina o papel é a condicional no
código, não o nome do arquivo.

---

## 0. Pré-login (sem papel definido)

Telas alcançáveis por qualquer pessoa, antes de existir sessão.

### Login (`/login`)

| Botão | O que faz | Objetivo |
|---|---|---|
| **Comunidade** (dropdown) | Seleciona o condomínio/bairro | Multi-tenancy: define o `community_id` do login |
| **Olho** (ícone na senha) | Alterna visibilidade da senha | Reduz erro de digitação |
| **Entrar** | Autentica e redireciona por papel | Entrada principal do app |
| **Esqueci minha senha** | Vai para `/forgot-password` | Recuperação por código de 6 dígitos |
| **Sou morador** | Vai para `/register/morador` | Cadastro de quem mora no bairro |
| **Sou prestador** | Vai para `/register/prestador` | Cadastro de quem oferece serviço |
| **Contatar administrador** | Abre o app de e-mail (`url_launcher`) | Canal de suporte para quem não consegue entrar |

### Cadastro de Morador (`/register/morador`)

| Botão | O que faz | Objetivo |
|---|---|---|
| **Comunidade** / **Condomínio** (dropdowns) | Selecionam onde a pessoa mora | Vinculam o usuário ao tenant correto |
| **Cadastrar** | Cria a conta (status `pending`) | Entrada na rede |
| **Já tenho cadastro** | Volta ao login | Saída do fluxo |

Os dois campos de **código de convite** são opcionais no formulário: sem os 2 códigos de
moradores distintos, a conta nasce `pending` e precisa de aprovação manual do admin.

### Cadastro de Prestador (`/register/prestador`)

| Botão | O que faz | Objetivo |
|---|---|---|
| **Comunidade** (dropdown) | Seleciona o bairro de atuação | Multi-tenancy |
| **Anos atuando no bairro** (dropdown) | Informa tempo de bairro | Alimenta o selo "Veterano" |
| **Chips de serviço** (`FilterChip`, multi-seleção) | Marcam as categorias oferecidas | Define onde o prestador aparece na busca |
| **Chip "Outros"** | Revela campo de texto livre | Cobre profissões fora das 17 categorias |
| **Checkbox de aceite de avaliações** | Aceita ser avaliado publicamente | **Obrigatório** — o botão Cadastrar fica desabilitado sem ele (backend rejeita com 400 e grava `ratings_acknowledged_at`) |
| **Cadastrar** | Cria a conta do prestador | Entrada na rede |
| **Já tenho cadastro** | Volta ao login | Saída do fluxo |

### Recuperar senha (`/forgot-password` → `/reset-password`)

| Botão | O que faz | Objetivo |
|---|---|---|
| **Comunidade** (dropdown) | Identifica o tenant | Necessário para localizar o usuário |
| **Enviar código** | Dispara e-mail com 6 dígitos (Resend) | Início da recuperação |
| **Olho** (senha) | Alterna visibilidade | Confirmação da nova senha |
| **Redefinir senha** | Grava a nova senha | Conclusão da recuperação |
| **Reenviar código** | Volta à tela anterior | Saída quando o código não chega |

### Aguardando aprovação (`/pending-approval`)

| Botão | O que faz | Objetivo |
|---|---|---|
| **Sair** | Faz logout | Única ação possível enquanto o cadastro está `pending` |

---

## 1. Botões globais (morador + prestador)

Ficam na **AppBar da Home**, que é compartilhada pelos dois papéis.

| Botão | O que faz | Objetivo |
|---|---|---|
| **Sino** (com badge de não lidas) | Abre `/notifications` | Central de notificações; o badge mostra a contagem não lida |
| **Balão de conversa** | Abre `/conversations` | Acesso ao chat interno |
| **Envelope** | Abre o e-mail do administrador | Suporte |
| **Sair** | Pede confirmação (**Cancelar** / **Sair**) e faz logout | Encerra a sessão; o diálogo evita logout acidental |

Presentes em quase toda tela interna:

- **Voltar** (`AppBackButton`) — volta na pilha do `go_router`.
- **Tentar de novo** (`AppErrorView`) — reexecuta o provider Riverpod que falhou, em vez de deixar a tela morta em erro.

---

## 2. MORADOR

### Home do morador (`/home`) — grade 2×3

| Tile | Destino | Objetivo |
|---|---|---|
| **Encontre um serviço** | `/service-picker` | Ponto de entrada da busca — escolhe primeiro a categoria |
| **Recomende um prestador** | `/recommend` | Endossar alguém em quem confia (alimenta o Score Aldeia) |
| **Mural de avisos** | `/bulletin` | Comunicação coletiva do bairro |
| **Convidar morador** | Abre diálogo de convite | Gera código de 72h; o novo morador precisa de **2 códigos de 2 moradores diferentes** — é o mecanismo que mantém a rede fechada |
| **Meus pedidos** | `/requests` | Pedidos de serviço abertos por ele |
| **Favoritos** | `/favorites` | Prestadores salvos |

**Diálogo "Convidar morador":** **Copiar código** (copia para a área de transferência e fecha) e **Fechar**.

Abaixo da grade, os cards de **"Em destaque hoje"** são tocáveis e abrem o perfil do prestador.

### Encontrar serviço (`/service-picker` → `/search`)

| Botão | O que faz | Objetivo |
|---|---|---|
| **Campo de busca** + **×** (limpar) | Filtra as 17 categorias em tempo real | Achar a categoria rápido |
| **Linha de categoria** | Abre `/search` já filtrado | Só é tocável se houver prestador na categoria |
| **Filtros** (ícone) | Abre a folha de filtros | Refinar o resultado |
| **Chips de categoria** ("Todos" + 17) | Filtram a lista | Troca de categoria sem voltar |
| **Chips de dia** ("Qualquer dia" + 7) | Filtram por disponibilidade | Achar quem atende no dia certo |
| **Ordenar por: Score / Nota / Indicações** | Reordena o resultado | Três leituras diferentes de reputação |
| **Aplicar** | Fecha a folha de filtros | Confirma a seleção |
| **Card de prestador** | Abre `/provider/:id` | Vai ao perfil |
| **Balão** / **Lista** (AppBar) | Abrem `/conversations` e `/requests` | Atalhos |

### Perfil do prestador (`/provider/:id`)

| Botão | O que faz | Objetivo |
|---|---|---|
| **Coração** | Favorita / desfavorita | Salvar para depois (some na auto-visualização) |
| **Perguntar** | Abre diálogo (**Cancelar** / **Enviar**) | Pergunta pública no perfil; notifica o prestador |
| **Responder** | Abre diálogo (**Cancelar** / **Enviar**) | Qualquer usuário pode responder — inclusive outro morador que já conhece o serviço |
| **Avaliar** | Abre `/rate/:id` | Avaliação detalhada (4 critérios) |
| **Contatar** | Cria conversa e abre `/chat/:id` | **Contato é sempre via chat interno — o telefone nunca é exposto** (decisão de produto) |

### Avaliar (`/rate/:id`)

Quatro linhas de estrelas — **Qualidade do serviço**, **Pontualidade**, **Educação**,
**Confiabilidade** — cada uma com 5 estrelas tocáveis, campo de comentário opcional e
**Enviar Avaliação**. Os 4 critérios alimentam o Score Aldeia.

### Recomendar (`/recommend` → `/recommend/:id`)

Busca por nome, item da lista abre a tela de recomendação: **linha de 5 estrelas** (nota
única, replicada nos 4 critérios do backend), comentário opcional e **Enviar avaliação**.
A recomendação é **anônima** para o prestador.

> ⚠️ **Colisão de nomenclatura.** O tile da home diz "Recomende um prestador", mas a tela de
> destino se intitula **"Avaliar prestador"** e o botão final é **"Enviar avaliação"** — as
> mesmas palavras do fluxo de **Avaliar** (`/rate/:id`), que é outra coisa: 4 critérios
> separados, entrada pelo perfil. São dois fluxos distintos com rótulos quase idênticos.
> Recomendar = endosso anônimo com nota única; Avaliar = avaliação detalhada e atribuída.

### Pedidos (`/requests`)

| Botão | O que faz | Objetivo |
|---|---|---|
| **Novo pedido** (FAB) | Abre `/requests/new` | **Só o morador cria pedido** — o FAB é escondido para prestador e o backend bloqueia com 403 |
| **Card de pedido** | Abre `/requests/:id` | Detalhe |
| **O que você precisa?** / **Categoria** (dropdown) / **Detalhes** | Campos do formulário | Categoria é opcional ("Geral" por padrão) |
| **Publicar pedido** | Cria o pedido | Publica para os prestadores da comunidade |

**No detalhe, como dono do pedido:**

| Botão | O que faz | Objetivo |
|---|---|---|
| **Encerrar pedido** | Muda o status para `closed` | Tira o pedido da lista de abertos |
| **Conversar** (por resposta) | Abre chat com aquele prestador | Fechar o combinado no chat interno |

### Mural (`/bulletin`), Favoritos, Chat, Notificações

- **Mural:** campo de texto + **enviar** (avião) — o aviso entra como **pendente** e só aparece após aprovação do admin.
- **Favoritos:** cada card abre o perfil.
- **Conversas:** cada linha abre `/chat/:id`; no chat, campo de mensagem + **enviar**.
- **Notificações:** cada item navega conforme o tipo (resposta a pedido → o pedido; avaliação/recomendação → painel; pergunta → o próprio perfil). Abrir a tela marca tudo como lido.

---

## 3. PRESTADOR

### Home do prestador (`/home`) — grade 2×3

| Tile | Destino | Objetivo |
|---|---|---|
| **Cadastre suas habilidades** | `/prestador/skills` | Define em quais categorias ele aparece |
| **Anuncie seu trabalho** | `/prestador/anuncio` | Bio profissional do perfil |
| **Minha agenda** | `/prestador/agenda` | Dias e horários de atendimento |
| **Meu painel** | `/dashboard` | Métricas de 30 dias (visualizações, contatos) |
| **Ver meu perfil público** | `/provider/{próprio id}` | Ver o perfil como o morador vê |
| **Pedidos abertos** | `/requests` | Demanda da comunidade |

### Habilidades (`/prestador/skills`)

| Botão | O que faz | Objetivo |
|---|---|---|
| **Busca** + **×** | Filtra as 17 categorias | Achar a categoria rápido |
| **Checkbox por categoria** | Marca/desmarca o serviço | Define a visibilidade na busca |
| **Switch "Preciso de auxílio com transporte"** | Revela as duas opções abaixo | Sinaliza necessidade logística |
| **Transporte público** / **Auxílio com combustível** (radio) | Escolhe o tipo | Detalha a necessidade |
| **Salvar** | `PUT /providers/me` (patch-style) | Salva só este slice, sem apagar bio/agenda |

### Anúncio (`/prestador/anuncio`)

Campo de bio + **Salvar** — texto que aparece no perfil público e conta para o selo "Perfil completo".

### Agenda (`/prestador/agenda`)

| Botão | O que faz | Objetivo |
|---|---|---|
| **Switch por dia** (7) | Liga/desliga o dia | Define se atende naquele dia |
| **Botões de horário** (início/fim) | Abrem o time picker | Define a janela de atendimento |
| **×** (por horário) | Remove aquele horário | Só aparece com mais de um horário no dia |
| **Adicionar horário** | Cria outro intervalo no mesmo dia | Permite manhã e tarde separadas |
| **Salvar disponibilidade** | Envia todos os slots | Valida fim > início e sobreposição antes de enviar |

### Perfil e pedidos (papel do prestador)

No **próprio perfil** (`isSelf`), somem: coração, **Perguntar**, **Avaliar**, **Contatar** e
a seção de Avaliações. Ele ainda pode usar **Responder** nas perguntas que recebeu.

No **detalhe de um pedido de outra pessoa**: campo de mensagem + **Tenho interesse** (uma
resposta por pedido — a segunda tentativa retorna 409). Depois de responder, o botão é
substituído por um aviso de confirmação e quem inicia a conversa é o morador.

---

## 4. ADMIN

O admin **não tem home de morador nem de prestador** — o router o manda direto para `/admin`,
e bloqueia qualquer outro papel de entrar lá. As 4 abas são a superfície inteira do papel.

| Botão | O que faz | Objetivo |
|---|---|---|
| **Sair** (AppBar) | Logout com confirmação | Encerra a sessão |
| **Abas: Visão Geral / Usuários / Mural / Comunidades** | Trocam de aba | Navegação do painel |

### Aba Visão Geral — 8 cards de estatística, todos tocáveis

Cada card abre uma folha inferior com a lista por trás do número:

| Card | O que a folha mostra |
|---|---|
| **Moradores** | Lista de moradores com status |
| **Prestadores** | Lista de prestadores com status |
| **Categorias de serviço** | As 17 categorias + quantos prestadores em cada |
| **Serviços oferecidos** | Pares prestador → categoria |
| **Pedidos de serviço** | Todos os pedidos (autor, categoria, status) |
| **Avaliações** | Quem avaliou quem, comentário e média |
| **Recomendações** | Quem recomendou quem |
| **Avisos pendentes** | *Não abre folha* — pula para a aba Mural |

### Aba Usuários

| Botão | O que faz | Objetivo |
|---|---|---|
| **Check verde** (só em usuários `pending`) | Abre confirmação e ativa o usuário | **Backup manual**: ativa quem não conseguiu os 2 códigos de convite. O diálogo (**Cancelar** / **Ativar**) alerta explicitamente que a pessoa não teve indicação de outros moradores |

Cada prestador exibe o registro do **aceite de avaliações públicas** (data/hora, ou "sem
aceite registrado" para cadastros anteriores a 12/07/2026 — não é irregularidade).

### Aba Mural

| Botão | O que faz | Objetivo |
|---|---|---|
| **Aprovar** | Publica o aviso no mural | Moderação — nenhum aviso vai ao ar sem passar por aqui |
| **Rejeitar** | Descarta o aviso | Moderação |

### Aba Comunidades

Formulário (Nome, Slug, Cidade, Estado) + **Criar Comunidade** — cria um novo tenant.
A lista abaixo é apenas informativa (sem editar nem excluir).

---

## 5. Observações

**Assimetrias de acesso entre os papéis** (podem ser intencionais, mas vale confirmar):

1. **O prestador não alcança o Mural de avisos.** A tela `/bulletin` existe e ele teria
   permissão, mas não há nenhum tile na home dele — só o morador tem. Ele não consegue ler
   nem publicar avisos da comunidade.
2. **O prestador não alcança Favoritos nem a Busca.** Também sem tile. Faz sentido para
   Favoritos, menos óbvio para a busca (um prestador pode querer contratar outro).
3. **O morador não tem "Meu painel"** — correto, as métricas são do prestador.

**Sem botão de destruição em lugar nenhum:** não existe excluir conta, excluir avaliação,
excluir pedido (só encerrar) nem suspender usuário pela UI. O admin só ativa, aprova e
rejeita. Remoções hoje só via SQL direto.

**Um botão sem gate de papel:** **Responder** nas perguntas do perfil aparece para qualquer
usuário em qualquer pergunta (inclusive de morador para morador). É o comportamento
desenhado — a pergunta é pública e a resposta também — mas é o único ponto onde não há
distinção de papel.
