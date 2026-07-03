---
tokens:
  colors:
    primary:
      50: "#EAF2F5"
      100: "#CBE0E8"
      200: "#A2C8D4"
      300: "#78AFC0"
      400: "#5695AC"
      500: "#457D94"
      600: "#386B80"
      700: "#2E5C74"   # âncora — Azul Sereno, aprovado pelo usuário em v1.1
      800: "#244A5D"   # estado pressed
      900: "#17242E"   # uso raro — texto sobre fundo claro em telas de altíssimo contraste
    secondary:
      50: "#FBEEE6"
      100: "#F5D7C3"
      200: "#EDBB99"
      300: "#E39E6E"
      400: "#D68C58"
      500: "#C97B4A"   # âncora — Terracota, aprovado pelo usuário em v1.1
      600: "#B1663A"
      700: "#94532E"
      800: "#784224"
      900: "#5C331B"
    accent:
      500: "#E3A83F"   # Dourado Suave — reservado para estrelas de avaliação
    error:
      900: "#B0223C"   # Carmim — deslocado de vermelho puro para se afastar do laranja/terracota na roda de cor
    informational:
      700: "#5B4B8A"   # Roxo Neutro — selo "Completo"
      900: "#3E3564"   # Roxo Neutro escuro — ScoreBadge "Novo"
    veteran:
      900: "#4A4038"   # Grafite Quente — selo "Veterano" (neutro, não compete com secondary)
    neutral:
      0: "#FFFFFF"
      50: "#F9FAFA"
      100: "#F1F2F1"
      200: "#E0E1E0"
      300: "#BDBEBD"
      400: "#9E9F9E"   # DEPRECATED — mesmo problema de contraste do sistema anterior, mantido só como registro
      500: "#757675"
      600: "#616261"   # texto secundário e hint
      700: "#424342"
      800: "#212221"
      900: "#1A1A1A"   # texto primário
    semantic:
      background: "{neutral.0}"
      surface: "{neutral.50}"
      text_primary: "{neutral.900}"
      text_secondary: "{neutral.600}"
      text_hint: "{neutral.600}"
      text_disabled: "{neutral.400}"
      border_default: "{neutral.300}"
      border_focus: "{primary.700}"
      border_error: "{error.900}"
      success: "{primary.700}"        # deliberadamente NÃO verde — ver seção Cores
      danger: "{error.900}"
    badges:
      bem_avaliado:   { bg: "{primary.700}",       text: "{neutral.0}",   contrast: 7.24 }
      muito_indicado: { bg: "{secondary.500}",     text: "{neutral.900}", contrast: 5.32 }
      veterano:       { bg: "{veteran.900}",       text: "{neutral.0}",   contrast: 10.09 }
      completo:       { bg: "{informational.700}", text: "{neutral.0}",   contrast: 7.45 }
    score_badge_bands:
      excelente:        { min: 85,          bg: "{primary.700}",       text: "{neutral.0}",   contrast: 7.24 }
      bom:               { min: 65, max: 84, bg: "{secondary.500}",     text: "{neutral.900}", contrast: 5.32 }
      precisa_melhorar:  { max: 64,          bg: "{error.900}",         text: "{neutral.0}",   contrast: 6.68 }
      novo:              { min_reviews: 5,   bg: "{informational.900}", text: "{neutral.0}",   contrast: 11.06 }
  typography:
    families:
      display: "Poppins"
      body: "Inter"
    scale:
      display:  { family: Poppins, size: 26, line_height: 34, weight: 700 }
      headline: { family: Poppins, size: 20, line_height: 28, weight: 600 }
      title:    { family: Poppins, size: 16, line_height: 22, weight: 600 }
      body:     { family: Inter,   size: 15, line_height: 22, weight: 400 }
      label:    { family: Inter,   size: 14, line_height: 20, weight: 600 }
      caption:  { family: Inter,   size: 12, line_height: 16, weight: 400 }
  rounded:
    xs: 4
    sm: 8
    md: 12
    lg: 16
    full: 999
  spacing:
    space_1: 4
    space_2: 8
    space_3: 12
    space_4: 16
    space_5: 20
    space_6: 24
    space_8: 32
    space_10: 40
    space_12: 48
    space_16: 64
  elevation:
    level_0: "none"
    level_1: "0 1px 2px rgba(23,36,46,0.08)"
    level_2: "0 2px 6px rgba(23,36,46,0.12)"
    level_3: "0 8px 24px rgba(23,36,46,0.16)"
  components:
    touch_target_min: 44
    button:
      height: 52
      radius: "{rounded.lg}"
      padding_horizontal: "{spacing.space_6}"
    input:
      radius: "{rounded.md}"
      padding_horizontal: 16
      padding_vertical: 14
    card:
      radius: "{rounded.lg}"
      elevation: "{elevation.level_2}"
      padding: "{spacing.space_4}"
    chip:
      height: 36
      radius: "{rounded.full}"
      padding_horizontal: "{spacing.space_4}"
    appbar:
      height: 56
      elevation: "{elevation.level_0}"
    score_badge:
      diameter: 48
      shape: "{rounded.full}"
---

# Aldeia Indica — Design System (v1.1)

Guia de decisões visuais e de interação do app Aldeia Indica.

## Revisão de paleta (v1.1) — por que não é mais verde

A v1.0 deste documento usava verde floresta como cor primária. Ao pedido do
time para explorar alternativas mais confortáveis para os olhos, pesquisa
adicional revelou um problema mais sério do que conforto visual: **a
combinação que já estava em produção — primary verde escuro, selo
"veterano" marrom, estado de erro vermelho — é praticamente o pior caso
possível para daltonismo vermelho-verde**, a forma mais comum de deficiência
de visão de cor (cerca de 8% dos homens). Verde escuro e marrom são
classicamente confundidos entre si nessa condição, e vermelho/verde é o par
de confusão mais citado em qualquer guia de acessibilidade cromática.

A paleta atual troca a base para **azul**, hue citado de forma consistente
como o mais seguro entre todos os tipos de daltonismo (protanopia,
deuteranopia, tritanopia) — é a base dos dois padrões mais referenciados
para paletas seguras, o Okabe-Ito e o Wong palette, ambos construídos sobre
azul combinado com laranja. Terracota como secundária replica exatamente
essa lógica, com a vantagem de também ser uma cor mais desaturada — o que
reduz fadiga visual em uso prolongado, o outro objetivo que motivou a
revisão.

Verde foi removido do sistema por completo, inclusive do token `success`
(reatribuído para a própria cor primária) — manter verde em qualquer
estado, mesmo que só em "sucesso", reintroduziria o mesmo conflito
vermelho-verde nos estados de confirmação/erro do app.

## Overview

Aldeia Indica conecta moradores e prestadores de serviço dentro do mesmo
bairro, começando pela Aldeia da Serra. O público inclui faixa etária mais
alta e pessoas com baixo letramento digital.

**Princípio central: confiança é visível.** Selos, avaliações e notas
precisam ser lidos corretamente em menos de um segundo, por qualquer
pessoa, em qualquer condição de visão de cor.

**O que este produto não é:**

- Não é um marketplace de gig economy.
- Não é um dashboard corporativo cinza-sobre-branco.
- Não é um produto que troca clareza por sofisticação.
- Não é um app "de banco" — o azul escolhido é deliberadamente mais suave e
  mais quente (por causa do par terracota) do que o azul-marinho saturado
  de apps financeiros, para não perder a personalidade de vizinhança.

---

## Colors

### Azul Sereno — Primary

| Token | Hex | Papel |
|---|---|---|
| `primary-50` | `#EAF2F5` | fundo muito claro, tints |
| `primary-100` | `#CBE0E8` | fundo de chip/selo não saturado |
| `primary-300` | `#78AFC0` | ilustrações, estados leves |
| `primary-500` | `#457D94` | uso intermediário |
| `primary-700` | `#2E5C74` | **âncora aprovada** — cor de marca padrão: botões, AppBar, selos, ScoreBadge |
| `primary-800` | `#244A5D` | estado pressed |
| `primary-900` | `#17242E` | uso raro, texto de altíssimo contraste |

> **Regra da Cor com Significado.** Nenhuma cor entra no app sem um
> significado nomeado. `primary-700` é a única cor que representa "isto é
> uma ação ou elemento da marca" — se um componente novo precisa dessa
> mesma leitura, ele usa esse token, não um azul digitado à mão.

### Terracota — Secondary

| Token | Hex | Papel |
|---|---|---|
| `secondary-100` | `#F5D7C3` | fundo leve |
| `secondary-500` | `#C97B4A` | **âncora aprovada** — selo "Muito indicado", faixa "Bom" do ScoreBadge |
| `secondary-700` | `#94532E` | texto sobre fundo claro de secondary |
| `secondary-900` | `#5C331B` | uso raro, alto contraste |

### Cores de apoio

| Token | Hex | Papel | Por que este hue |
|---|---|---|---|
| `accent-500` | `#E3A83F` | estrelas de avaliação | dourado, mais amarelo que terracota — permanece distinto a olho nu e para daltônicos |
| `error-900` | `#B0223C` | erro, ação de perigo | carmim, deslocado de vermelho puro para não colidir com o terracota na roda de cor |
| `informational-700` | `#5B4B8A` | selo "Completo" | roxo neutro — precisa ser visualmente distinto do primary agora que primary é azul |
| `informational-900` | `#3E3564` | ScoreBadge "Novo" | roxo neutro escuro |
| `veteran-900` | `#4A4038` | selo "Veterano" | grafite quente, neutro — não compete em hue com secondary |

### Por que quatro selos usam quatro hues diferentes

Isto é deliberado, não estético: `primary` (azul), `secondary` (terracota),
`informational` (roxo) e `veteran` (grafite quente) foram escolhidos para
ficarem em posições afastadas da roda de cor entre si, e nenhum deles é
verde ou depende de diferenciar vermelho de verde. Um usuário com
daltonismo vermelho-verde — o tipo mais comum — consegue distinguir os
quatro sem depender de percepção fina de matiz.

| Selo | Fundo | Texto | Contraste |
|---|---|---|---|
| `bem_avaliado` | `primary-700` `#2E5C74` | branco | **7.24:1** |
| `muito_indicado` | `secondary-500` `#C97B4A` | grafite `#1A1A1A` | **5.32:1** |
| `veterano` | `veteran-900` `#4A4038` | branco | **10.09:1** |
| `completo` | `informational-700` `#5B4B8A` | branco | **7.45:1** |

> **Regra do Selo Legível.** Nenhum texto sobre fundo de selo pode ficar
> abaixo de 4.5:1 — e, a partir desta versão, nenhum novo selo pode
> reutilizar um hue já usado por outro selo ou pelo `error`. Teste os dois
> critérios antes de shippar.

### ScoreBadge — 4 faixas

| Faixa | Nota | Fundo | Texto | Contraste |
|---|---|---|---|---|
| Excelente | ≥ 85 | `primary-700` | branco | **7.24:1** |
| Bom | 65–84 | `secondary-500` | grafite `#1A1A1A` (não branco — mesma correção da v1.0) | **5.32:1** |
| Precisa melhorar | < 65 | `error-900` `#B0223C` | branco | **6.68:1** |
| Novo | < 5 avaliações | `informational-900` `#3E3564` | branco | **11.06:1** |

A faixa "Bom" mantém a mesma correção documentada na v1.0: fundo saturado
(agora terracota, antes âmbar) precisa de texto escuro, não branco, para
passar em 4.5:1. Continua sendo o bug mais fácil de reintroduzir por
engano — teste sempre que a cor de fundo de um selo mudar.

### Neutros e texto

Sem alterações de fundo em relação à v1.0 — a correção do `textHint`
(`#9E9F9E` → reaproveitar `neutral-600` `#616261`, contraste **6.18:1**)
continua valendo, é independente da cor de marca.

### Success não é mais verde

`success` foi reatribuído para `primary-700` (o mesmo azul de marca).
Estados de sucesso e confirmações vêm sempre acompanhados de um ícone de
check — nunca só a cor — o que já era exigido pela Regra do Estado Duplo
para outros componentes e agora se aplica formalmente aqui também. Isso
evita reabrir, por uma porta lateral, o mesmo problema de contraste
vermelho-verde que motivou tirar o verde do resto do sistema.

---

## Typography

Sem alterações: **Poppins** (600–700) para títulos, **Inter** para corpo.
Ver tabela de escala completa no frontmatter (`typography.scale`).

> **Regra das Duas Fontes.** Poppins nunca em texto corrido de mais de uma
> linha. Inter nunca em títulos de tela.

---

## Elevation

Sombras recalculadas com a cor de sombra baseada no novo `primary-900`
(`#17242E`) em vez do verde escuro anterior — mesmo princípio, cor
diferente:

| Token | Valor |
|---|---|
| `elevation-1` | `0 1px 2px rgba(23,36,46,0.08)` |
| `elevation-2` | `0 2px 6px rgba(23,36,46,0.12)` (cards) |
| `elevation-3` | `0 8px 24px rgba(23,36,46,0.16)` (modais) |

Raio de borda sem alterações: `md` (12px) inputs, `lg` (16px) cards e
botões, `full` chips/avatares/ScoreBadge.

---

## Components

### Botões

| Variante | Fundo | Texto |
|---|---|---|
| Primário | `primary-700` | branco (7.24:1) |
| Secundário/outline | transparente, borda `primary-700` | `primary-700` |
| Texto/ghost | transparente | `primary-700` |
| Perigo | `error-900` `#B0223C` | branco (6.68:1) |

Estados: pressed usa `primary-800` (`#244A5D`); disabled/loading sem
alteração de estrutura em relação à v1.0.

### Cards, Inputs, Chips, Navegação, Ícones

Estrutura idêntica à v1.0 (raio, elevação, altura, padding) — só as cores
de marca mudam:

- Foco de input: borda `primary-700`, 2px.
- Chip selecionado: fundo `primary-100` `#CBE0E8`, texto `primary-700`.
- AppBar: fundo `primary-700`, texto branco, sem sombra.
- Navegação ativa: `primary-700`. Inativa: `neutral-600`.
- Ícones interativos: `primary-700`. Destaque pontual: `secondary-500`,
  uso esparso. Estrelas: `accent-500`, exclusivo.

### Acessibilidade

| Combinação | Contraste | Status |
|---|---|---|
| branco sobre `primary-700` | 7.24:1 | OK |
| grafite sobre `secondary-500` | 5.32:1 | OK |
| branco sobre `veteran-900` | 10.09:1 | OK |
| branco sobre `informational-700` | 7.45:1 | OK |
| branco sobre `error-900` | 6.68:1 | OK |
| branco sobre `informational-900` | 11.06:1 | OK |
| `neutral-600` sobre branco | 6.18:1 | OK |
| `neutral-400` sobre branco (descontinuado) | 2.68:1 | FALHA |

> **Regra da Roda de Cor.** Antes de adicionar qualquer cor nova ao
> sistema, verifique a posição dela na roda de cor contra as cinco já
> existentes (`primary`, `secondary`, `accent`, `error`, `informational`,
> `veteran`). Se ficar a menos de ~40° de outra, ou se depender de
> diferenciar vermelho de verde para ser lida corretamente, ela é
> rejeitada — não importa o quanto o contraste isolado esteja correto.

### Tema escuro

Decisão mantida sem alteração da v1.0: não existe tema escuro nesta
versão, por decisão deliberada (público prioritário com baixo letramento
digital e faixa etária mais alta).

---

## Do's and Don'ts

**Fazer:**

- Testar toda cor nova contra 4.5:1 **e** contra a roda de cor das cores
  já existentes antes de shippar.
- Reatribuir `success`/`error` para cores fora do eixo vermelho-verde.
- Emparelhar toda cor de estado (sucesso, erro, selecionado) com um ícone
  — nunca só cor.
- Reaproveitar os tokens desta escala em vez de digitar hex novo.

**Não fazer:**

- Não reintroduzir verde em nenhum token, nem "só" em `success` — é
  exatamente essa porta lateral que causava o conflito com o `error`
  vermelho.
- Não usar vermelho puro para erro sem checar a distância dele até o
  terracota da marca — por isso o erro é carmim (`#B0223C`), não vermelho
  puro.
- Não usar branco sobre `secondary-500` — falha contraste, use grafite.
- Não usar a mesma família de hue para dois selos diferentes.
