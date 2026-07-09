# Frontend Audit — Aldeia Indica (mobile/Flutter)

**Data:** 2026-07-08 · **Método:** /impeccable audit (registro: product) · **Baseline:** [frontend-audit-2026-07-02.md](frontend-audit-2026-07-02.md)

> **ADENDO 2026-07-09 — todas as ações executadas na sessão seguinte.** Score re-estimado: **17/20** (era 14/20).
> - **P1 tiles dourados:** `_HomeTile` agora decide o conteúdo por luminância (`ThemeData.estimateBrightnessForColor`) — fundos claros (dourado 8.24:1, terracota 5.32:1) recebem grafite, escuros mantêm branco. Cobre qualquer cor futura. O P3 dos tiles terracota foi resolvido pela mesma regra.
> - **Cinzas soltos:** 37 ocorrências migradas para tokens em 14 arquivos — `grep Colors.grey|0xFFE0E0E0|black87` retorna **zero** fora de `app_colors.dart`. Contrato do `accent500` atualizado no token file. `fontSize` 10-11 → 12 no admin/dashboard.
> - **Semantics:** ScoreBadge ("Score Aldeia: N de 100"), StarRatingBar ("Avaliação: X de 5 estrelas"), sino com contagem de não lidas no tooltip. Selos já tinham texto visível (anunciados nativamente).
> - **Alvos de toque:** `InteractiveStarRating` com piso de 48px por estrela + semântica de slider (onIncrease/onDecrease); `_CriterionRow` da tela Avaliar virou coluna para acomodar.
> - **Dynamic Type:** `\n` manuais removidos dos 12 labels de tile (wrap natural, maxLines 3), tiles crescem com `textScalerOf` (clamp 1.6). Testado ao vivo no simulador em XXXL — login reflui sem overflow; home requer login manual para verificação visual (automação de acessibilidade do macOS revogada).
> - **Documentação:** PRODUCT.md atualizado para a paleta v1.1 e tema claro único registrado como decisão de produto.
> - Novo score por dimensão: A11y 2→**3** (falta passada completa de VoiceOver para 4), Theming 2→**3** (rubrica exige dark mode para 4 — dispensado por decisão documentada), Responsividade 3→**4**, Performance **3** (skeletons P3 não feitos), Anti-Patterns **4**.

Todos os contrastes citados foram calculados (WCAG 2.x luminância relativa), não estimados.

## Audit Health Score

| # | Dimensão | Score | Achado-chave |
|---|----------|-------|--------------|
| 1 | Acessibilidade | 2/4 | Tiles dourados da home: branco sobre `accent500` = **2.11:1** (falha AA em navegação primária) |
| 2 | Performance | 3/4 | Sem problemas reais na escala atual; spinners centrais onde skeletons serviriam melhor |
| 3 | Responsividade | 3/4 | Tiles com `childAspectRatio` fixo + `\n` manual nos labels — risco com Dynamic Type (público 60+) |
| 4 | Theming | 2/4 | ~30 usos de `Colors.grey`/hex soltos fora dos tokens (eram 11 na auditoria de 02/07 — piorou) |
| 5 | Anti-Patterns | 4/4 | Paleta própria daltonismo-safe, sem tells; grid de tiles é decisão deliberada pró-público |
| **Total** | | **14/20** | **Good — atacar as dimensões fracas (era 13/20 em 02/07)** |

## Veredito de Anti-Patterns

**Passa.** Nenhum tell de geração automática: paleta Azul Sereno + Terracota é decisão documentada (Okabe-Ito, daltonismo-safe), tokens têm comentários de contraste no próprio código, o grid de tiles coloridos é um padrão launcher intencional para público com menor letramento digital (toque grande, alto contraste — exceto o achado P1 abaixo). O `AppErrorView` adicionado em 08/07 padronizou os estados de erro sem side-stripes nem decoração.

## Resumo Executivo

- **Score 14/20 (Good)** — subiu 1 ponto desde 02/07 (ScoreBadge e textHint corrigidos no rebrand).
- **1 P1, 4 P2, 5 P3.**
- O P1 é novo (introduzido pelo rebrand): dois tiles de navegação primária ilegíveis por contraste.
- Dois P2 são **recorrentes da auditoria de 02/07** (Semantics ausente, cores fora dos tokens) — e o de cores **piorou** (11 → ~30 ocorrências). Sem uma regra de lint, esse número vai continuar crescendo.

## Achados Detalhados

### P1 — Maior

#### [P1] Tiles dourados com texto/ícone brancos: 2.11:1 — falha AA em navegação primária
- **Local:** `home_screen.dart:152` ("Convidar morador", home do morador) e `:348` ("Meu painel", home do prestador) — ambos `color: AppColors.accent` no `_HomeTile`, que fixa `Colors.white` para ícone e label (`home_screen.dart:400-408`).
- **Categoria:** Acessibilidade / Theming.
- **Impacto:** dois botões da navegação principal ficam quase ilegíveis exatamente para o público-alvo declarado no PRODUCT.md (faixa etária alta, "contraste alto" como princípio #4). Além disso, `accent500` está documentado em `app_colors.dart:32` como "exclusivo estrelas" — o uso em tile viola o contrato do próprio token.
- **WCAG:** 1.4.3 (AA exige 4.5:1; texto 18px w600 é "large", exigiria 3:1 — 2.11:1 falha até isso; o ícone falha o 3:1 de componentes gráficos).
- **Correção (números verificados):** trocar o texto/ícone desses tiles para `neutral900` (**8.24:1** sobre dourado — mesmo padrão do ScoreBadge "Bom") **ou** trocar o fundo para `secondary700` (**5.94:1** com branco). A primeira opção exige parametrizar a cor do conteúdo no `_HomeTile`; a segunda é 2 linhas.

### P2 — Menor

#### [P2] `InteractiveStarRating`: alvo de toque de 32px, sem semântica
- **Local:** `shared/widgets/star_rating_bar.dart:51-67`; usado com `size: 32` em `rate_provider_screen.dart:147`.
- **Categoria:** Acessibilidade / Responsividade.
- **Impacto:** avaliar é a ação central do produto e cada estrela é um `GestureDetector` cru do tamanho do ícone — 32×32px, abaixo do mínimo de 44/48px, para um público de motricidade fina variável. Leitor de tela não anuncia nada (nem o valor atual, nem que é ajustável). A tela "Recomende" tem seu próprio `_StarRow` com 52px + padding — corrigir o widget compartilhado e reusar.
- **WCAG:** 2.5.8 (target size), 4.1.2 (name, role, value).
- **Correção:** envolver cada estrela em área mínima de 48px (`Padding`/`SizedBox`) e um `Semantics(slider: true, value: ..., label: 'Nota')` no conjunto.

#### [P2] `Colors.grey` solto (= `#9E9E9E`, 2.68:1) em textos pequenos — a mesma falha que o token file documenta como corrigida
- **Local (texto que falha):** `admin_dashboard_screen.dart:254,258` (fontSize 10-12), `dashboard_screen.dart:139,166` (fontSize 11-12), `pending_approval_screen.dart:51` (fontSize 15), `provider_card.dart:71` (`grey[500]`, fontSize 12).
- **Categoria:** Acessibilidade / Theming.
- **Impacto:** `app_colors.dart:61` registra que `#9E9E9E` "media 2.68:1 (falha AA)" e por isso `textHint` virou `neutral600` — mas 6+ textos continuam usando exatamente essa cor via `Colors.grey`. `grey[600]` (4.61:1) passa raspando; `neutral600` do token (6.13:1) é o substituto correto para todos.
- **WCAG:** 1.4.3.
- **Correção:** buscar-e-substituir dirigido: `Colors.grey` / `grey[500]` → `AppColors.textSecondary`; `grey[600]` → `AppColors.textSecondary`; fills `grey[100/200]` → `neutral100/200`.

#### [P2] Semantics: 1 ocorrência no app inteiro — recorrente de 02/07
- **Local:** única `semanticsLabel` é a logo do login (`login_screen.dart:74`). `ScoreBadge`, `StarRatingBar`, selos, badge de notificação: nenhum anúncio para leitor de tela.
- **Categoria:** Acessibilidade.
- **Impacto:** "Confiança é visível, não abstrata" (princípio #3) — hoje ela é *invisível* para quem usa VoiceOver: o score lê "47 score" como dois textos soltos, estrelas não leem nada, selos não leem nada.
- **Correção:** `Semantics(label: 'Score Aldeia: 47 de 100')` no ScoreBadge, `'Avaliação: 4,5 de 5 estrelas'` no StarRatingBar, label nos selos. ~1 linha por widget composto.

#### [P2] Dynamic Type não testado; labels dos tiles com `\n` manual
- **Local:** `home_screen.dart` — `GridView.count(childAspectRatio: 1)` + labels `'Encontre um\nserviço'` etc., fontSize fixo 18.
- **Categoria:** Responsividade.
- **Impacto:** iOS com texto grande (ajuste comum no público 60+) aumenta o texto dentro de tiles de altura fixa — overflow provável; as quebras `\n` manuais impedem o reflow natural e podem quebrar em palavra errada com escala maior.
- **Correção:** remover os `\n` (deixar o wrap natural com `maxLines: 2` + `TextOverflow.ellipsis` ou `FittedBox`), testar o app com Dynamic Type em 1.3× e 1.5× e ajustar `childAspectRatio`/padding conforme necessário.

### P3 — Polimento

#### [P3] Tiles terracota (branco sobre `secondary500` = 3.27:1) passam AA só por serem texto grande
- `home_screen.dart:140` ("Recomende...") e `:336` ("Anuncie..."). O DESIGN_1.md chama branco-sobre-secondary500 de "bug mais fácil de reintroduzir". Hoje é legal (18px w600 = large text, 3:1), mas está a um ajuste de fontSize de virar falha. Fundo `secondary700` (5.94:1) elimina o risco.

#### [P3] Sem tema escuro — decisão pendente desde 02/07
- `app.dart` só define `theme: AppTheme.light`. Aceitável para o registro (produto, público específico), mas registrar a decisão em DESIGN/PRODUCT.md para parar de reaparecer em auditoria.

#### [P3] 28 spinners centrais onde skeletons serviriam melhor
- Feeds principais (busca, pedidos, conversas) usam `CircularProgressIndicator` central. Registro product prefere skeleton nos 2-3 feeds de maior tráfego. Baixa urgência.

#### [P3] PRODUCT.md desatualizado sobre a marca
- "verde floresta + âmbar quente" é a paleta v1.0; o rebrand v1.1 (Azul Sereno + Terracota, daltonismo-safe) é a fonte da verdade desde 03/07. Atualizar para não guiar decisões futuras com a paleta errada.

#### [P3] `fontSize: 10` no painel admin
- `admin_dashboard_screen.dart:258` — pequeno até para tela interna; subir para ≥12.

## Padrões Sistêmicos

1. **Cores fora do token crescem sem freio:** 11 ocorrências em 02/07 → ~30 em 08/07. Toda tela nova adiciona `Colors.grey[...]`. Sem uma regra (lint custom, convenção no CLAUDE.md/conventions.md, ou revisão), a próxima auditoria vai achar 50.
2. **Contraste é tratado com cuidado nos tokens e ignorado fora deles:** os comentários de contraste em `app_colors.dart`/`score_badge.dart` são exemplares — mas `Colors.grey` e os tiles accent mostram que o cuidado não alcança o código que não passa pelos tokens. A regra sistêmica é uma só: *cor nova = token novo, com ratio calculado no comentário*.

## Pontos Positivos

- **Token file exemplar:** escalas completas 50-900, aliases semânticos, e comentários de contraste com números no próprio código (`textHint`, `success`, ScoreBadge) — prática rara e que já evitou regressões.
- **Dois achados da auditoria anterior corrigidos:** ScoreBadge "Bom" (P1 de 02/07) e `textHint` (P3) — ambos com comentário explicando o porquê.
- **`AppErrorView` (08/07):** estados de erro consistentes com retry religado ao provider certo em 20 telas — resolve a categoria inteira de "erro cru na UI".
- **Empty states que ensinam:** "Sem conversas ainda. Contacte um prestador!" orienta a próxima ação em vez de só constatar o vazio.
- **Formulários com `labelText`** (label flutua, não desaparece ao digitar) — decisão certa para o público.
- **Tooltips em todos os IconButtons da AppBar.**
- **Paleta daltonismo-safe deliberada** (Okabe-Ito) com verde removido até do `success` — decisão de design real e documentada.

## Ações Recomendadas (ordem de prioridade)

1. **[P1] `/impeccable colorize`** — corrigir os tiles dourados (conteúdo `neutral900` @ 8.24:1 ou fundo `secondary700` @ 5.94:1), dar folga aos tiles terracota, e migrar os ~30 `Colors.grey`/hex soltos para os tokens (os números de substituição já estão calculados acima).
2. **[P2] `/impeccable harden`** — `Semantics` nos widgets compostos (ScoreBadge, StarRatingBar, selos) + alvo de 48px e semântica de slider no `InteractiveStarRating`.
3. **[P2] `/impeccable adapt`** — teste com Dynamic Type 1.3×/1.5×, remover `\n` manuais dos tiles, validar overflow.
4. **[P3] `/impeccable document`** — registrar a decisão do tema escuro e atualizar PRODUCT.md para a paleta v1.1.
5. **`/impeccable polish`** — passada final depois das correções.
