# Frontend Audit — Aldeia Indica (mobile/Flutter)

**Data:** 2026-07-02
**Escopo:** app Flutter completo (`mobile/`) — 49 arquivos Dart, `lib/core` + `lib/features/*` + `lib/shared`.
**Ferramenta:** skill `impeccable`, comando `audit` (checagem técnica estática — não é crítica visual/UX).
**Metodologia:** leitura de `app_theme.dart`/`app_colors.dart` (sistema de tokens), varredura de todos os arquivos de `lib/features` e `lib/shared` por padrão (grep) e leitura direta dos componentes onde o padrão apareceu, para confirmar cada achado antes de reportar (sem análise em runtime/browser — Flutter não permite os mesmos scripts de captura de contraste do skill original, feito por cálculo manual de contraste WCAG a partir dos valores hex reais do código).

## Audit Health Score

| # | Dimensão | Nota | Achado principal |
|---|---|---|---|
| 1 | Acessibilidade | 2/4 | `ScoreBadge` — texto branco sobre `AppColors.secondary` (#F57F17): contraste ~2.65:1, falha WCAG AA |
| 2 | Performance | 3/4 | Bom uso de `const` (535 ocorrências); `ListView.builder` usado nas listas longas reais |
| 3 | Responsividade | 3/4 | `SafeArea` presente em 9 telas; nenhuma largura fixa problemática encontrada |
| 4 | Theming | 2/4 | 11 cores hex soltas fora do token file; 15 arquivos usam `Colors.grey`/`Colors.black` direto; sem dark mode |
| 5 | Anti-Patterns | 3/4 | App Flutter/Material — a maioria dos "AI slop tells" do skill (gradiente em texto, glassmorphism, grid de cards idênticos) é um domínio web/CSS e não se aplica aqui; achado real é o padrão ad-hoc de cores de selo |
| **Total** | | **13/20** | **Aceitável (trabalho significativo necessário)** |

## Veredito de Anti-Patterns

**Não parece "AI slop" no sentido do skill original (que mira padrões de landing page web).** Este é um app Flutter Material 3 convencional, sem gradiente decorativo em texto, sem glassmorphism, sem "hero metric template" — esses padrões não se manifestam do mesmo jeito em UI mobile nativa. O achado real de consistência é mais modesto: cada tipo de selo (`bem_avaliado`, `muito_indicado`, `veterano`, `completo`) tem uma cor própria não sistematizada (ver P2 abaixo), o que é inconsistência de design system, não "slop" propriamente dito.

## Resumo Executivo

- **Nota geral: 13/20 (Aceitável)**
- 1 achado P1 (WCAG AA real, em componente de alta visibilidade), 3 achados P2, 2 achados P3
- **Top 3:**
  1. `ScoreBadge` (selo de nota do prestador) falha contraste WCAG AA — usado em 3 telas centrais do app (busca, perfil, dashboard do prestador)
  2. Zero uso de `Semantics()` em qualquer widget customizado do app — leitores de tela dependem só do comportamento padrão do Material
  3. Sistema de cores tem 11 valores hex soltos fora do token file, incluindo cores que nem existem na paleta oficial (`0xFF6A1B9A`, `0xFF5D4037`, `0xFF1565C0`)

## Achados Detalhados

### P1 — Maior

#### [P1] `ScoreBadge`: texto branco sobre fundo âmbar falha contraste WCAG AA
- **Localização:** `lib/shared/widgets/score_badge.dart:28-42`
- **Categoria:** Acessibilidade
- **Impacto:** O selo "Score Aldeia" (0-100, exibido em círculo colorido) usa `AppColors.secondary` (#F57F17) como fundo quando a nota está entre 65-84, com texto branco (`Colors.white` para o número, `Colors.white70` para o rótulo "score") por cima. Contraste calculado: **~2.65:1** para o texto branco sólido — bem abaixo do mínimo de 4.5:1 (texto normal) e mesmo do 3:1 (texto grande). Para o rótulo "score" em `Colors.white70` o contraste é ainda pior. Esse selo é exatamente o elemento que materializa o princípio "confiança é visível" do produto — e é o menos legível da tela para uma faixa de nota inteira (65-84, provavelmente a mais comum).
- **Padrão/Norma:** WCAG 2.1 AA — 1.4.3 Contraste Mínimo
- **Recomendação:** Trocar o texto para uma cor escura (`AppColors.textPrimary` ou preto) quando o fundo for `AppColors.secondary`, ou escurecer a variante usada como fundo do badge nessa faixa de nota. Testar as 3 variantes de cor (`success`, `secondary`, `Colors.grey`) com o texto branco atual — `success` (#2E7D32, verde escuro) provavelmente passa; `secondary` não passa.
- **Comando sugerido:** `/impeccable colorize` (ou `/impeccable polish` no componente específico)

### P2 — Menor

#### [P2] Nenhum uso de `Semantics()` em nenhum widget customizado
- **Localização:** todo `lib/features/*` e `lib/shared/widgets/*` (0 ocorrências de `Semantics(`)
- **Categoria:** Acessibilidade
- **Impacto:** Widgets Material padrão (`ElevatedButton`, `TextField`, `AppBar`) já carregam semântica razoável por padrão do Flutter, mas componentes customizados e compostos — `ScoreBadge`, `StarRatingBar`, os selos de verificação (`bem_avaliado`/`muito_indicado`/etc.), os chips de categoria — não têm nenhum `Semantics(label: ...)` explícito. Um leitor de tela provavelmente anuncia esses elementos de forma incompleta ou genérica (ex: apenas o número da nota, sem contexto de que é uma "nota de confiança"). Dado que o público declarado do app inclui usuários com necessidades de acessibilidade e baixo letramento digital, isso é uma lacuna real, não teórica.
- **Recomendação:** Adicionar `Semantics(label: 'Nota de confiança: ${score.round()} de 100', ...)` no `ScoreBadge` e equivalentes nos outros widgets compostos de `lib/shared/widgets/`.
- **Comando sugerido:** `/impeccable harden`

#### [P2] Cores fora do sistema de tokens — 11 ocorrências, incluindo cores inéditas
- **Localização:** `lib/features/home/presentation/home_screen.dart:115` (`#6A1B9A`, roxo — não existe em `app_colors.dart`), `lib/features/provider_profile/presentation/profile_screen.dart:108-111` (`#F57F17`, `#1B5E20`, `#5D4037`, `#1565C0` — os dois primeiros duplicam tokens existentes por valor bruto ao invés de referenciar `AppColors`, os dois últimos são cores novas não documentadas), `lib/features/chat/presentation/chat_screen.dart:65`, `lib/features/dashboard/presentation/dashboard_screen.dart:58,150`, `lib/features/recommendations/presentation/recommend_provider_screen.dart:123`, `lib/shared/widgets/loading_overlay.dart:16`.
- **Categoria:** Theming
- **Impacto:** Sistema de selos de verificação do prestador (`bem_avaliado`, `muito_indicado`, `veterano`, `completo`) usa 4 cores ad-hoc sem relação sistemática entre si nem com a paleta principal — dificulta manter consistência visual e onboarding de novos contribuidores (teriam que adivinhar de onde vieram essas cores). Adicionalmente, 15 arquivos usam `Colors.grey`/`Colors.black` do Flutter diretamente ao invés de `AppColors.textSecondary`/`textPrimary`.
- **Recomendação:** Adicionar ao `AppColors` uma seção `sealColors` nomeada (ex: `sealVeterano`, `sealCompleto`) e trocar todas as ocorrências de hex solto por referências ao token file — incluindo os 4 casos que já duplicam `primary`/`secondary` por valor.
- **Comando sugerido:** `/impeccable colorize`

#### [P2] Sem tema escuro
- **Localização:** `lib/core/theme/app_theme.dart` — só existe `AppTheme.light`, nenhum `AppTheme.dark`
- **Categoria:** Theming
- **Impacto:** O app sempre renderiza no tema claro, independente da preferência do sistema operacional do usuário. Não é necessariamente um bug de UX para este público (usuários mais velhos podem preferir tema claro por padrão), mas é uma lacuna de theming que vale uma decisão explícita, não uma omissão.
- **Recomendação:** Decidir deliberadamente: ou implementar `AppTheme.dark` e ligar `darkTheme:`/`themeMode:` no `MaterialApp`, ou documentar em `docs/conventions.md` que o app é intencionalmente light-only (e por quê) para não parecer uma lacuna esquecida.
- **Comando sugerido:** `/impeccable document` (documentar a decisão) ou implementar via `/impeccable craft dark theme`

### P3 — Polimento

#### [P3] Token `textHint` (#9E9E9E) definido mas nunca usado — risco latente de contraste
- **Localização:** `lib/core/constants/app_colors.dart:17`
- **Categoria:** Acessibilidade / Theming
- **Impacto:** `AppColors.textHint` não é referenciado em nenhum lugar do código hoje — não é um bug ativo. Mas seu valor (#9E9E9E sobre branco) calcula **~2.68:1** de contraste, abaixo do mínimo de 4.5:1. Se um contribuidor futuro adotar esse token para texto de placeholder/hint (uso óbvio dado o nome), reintroduz exatamente a falha de contraste que o skill Impeccable aponta como o erro mais comum em UI gerada por IA ("texto cinza claro em quase-branco").
- **Recomendação:** Escurecer o valor do token agora (ex: para `#616161`, igual a `textSecondary`, que já passa em 6.19:1) antes que alguém o use, ou removê-lo se realmente não tem uso planejado.
- **Comando sugerido:** `/impeccable colorize`

#### [P3] `ListView(children: [...])` em 3 telas ao invés de `.builder`
- **Localização:** `lib/features/providers_list/presentation/search_screen.dart`, `lib/features/prestador/presentation/skills_screen.dart`, `lib/features/prestador/presentation/agenda_screen.dart`
- **Categoria:** Performance
- **Impacto:** Nenhum problema real hoje — as três listas são de tamanho fixo e pequeno (17 categorias de serviço, 7 dias da semana), então a diferença de performance entre `ListView` e `ListView.builder` é irrelevante nesse volume. Listado apenas para consciência caso essas listas cresçam.
- **Recomendação:** Nenhuma ação necessária agora. Só migrar para `.builder` se a fonte de dados deixar de ser um conjunto fixo pequeno.

## Padrões Sistêmicos

- **Cores soltas fora do token file aparecem em 7+ arquivos** (theming) — indica que não há revisão de PR garantindo uso exclusivo de `AppColors`, não é um erro isolado.
- **Ausência total de `Semantics()` em qualquer widget composto** (acessibilidade) — não é uma tela esquecida, é a ausência completa de um padrão no projeto inteiro.

## Pontos Positivos

- **Uso saudável de `const`** (535 ocorrências) — bom sinal de performance/rebuilds desnecessários evitados.
- **`ListView.builder` usado corretamente onde a lista é realmente longa/dinâmica** (6 ocorrências — chat, listagens de prestadores).
- **Nenhuma tela desabilita escala de texto do sistema** (`textScaleFactor`/`TextScaler.noScaling` não aparece em lugar nenhum) — respeita a preferência de acessibilidade do usuário por padrão, importante dado o público do produto.
- **`SafeArea` usado de forma razoável** (9 telas) e nenhuma largura fixa problemática encontrada além de um caso isolado e de baixo risco.
- **Paleta principal (`AppColors`) é bem definida e usada consistentemente na maior parte do app** — o problema é a minoria de exceções, não a ausência de sistema.

## Ações Recomendadas (ordem de prioridade)

1. **[P1] `/impeccable colorize`** — corrigir contraste do `ScoreBadge` (texto sobre `secondary`)
2. **[P2] `/impeccable harden`** — adicionar `Semantics()` aos widgets compostos (`ScoreBadge`, `StarRatingBar`, selos)
3. **[P2] `/impeccable colorize`** — sistematizar cores de selo e eliminar hex soltos fora do token file
4. **[P2] `/impeccable document`** — registrar a decisão sobre tema escuro (implementar ou documentar como intencional)
5. **[P3] `/impeccable colorize`** — corrigir ou remover o token `textHint` não utilizado
6. **`/impeccable polish`** — passe final depois dos itens acima

Você pode pedir pra eu rodar esses comandos um de cada vez, todos de uma vez, ou na ordem que preferir.

Rode `/impeccable audit` de novo depois dos fixes pra ver a nota subir.
