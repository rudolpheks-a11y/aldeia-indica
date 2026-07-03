# Aldeia Indica — Guia da Marca

> Rede de confiança comunitária para moradores e prestadores de serviços de bairros residenciais.

**v1.1.** A paleta migrou de verde para azul + terracota — ver [DESIGN_1.md](DESIGN_1.md)
(design system completo, tokens) e [aldeia_indica_manual_visual_1.html](aldeia_indica_manual_visual_1.html)
(manual visual renderizado, abrir no navegador) para o racional completo e a especificação
componente a componente. Este arquivo continua sendo o resumo rápido de uso da marca.

---

## 1. Essência

**Propósito.** Transformar as recomendações soltas dos grupos de WhatsApp em um histórico estruturado de confiança entre vizinhos e prestadores de serviço.

**Personalidade.** Acolhedora, confiável, local, vizinha. Não é um marketplace frio — é a praça do bairro em formato de app.

**Conceito do logo.** Uma **casa aninhada na serra, sob o sol nascente**. A casa é o lar e o pertencimento; a serra remete diretamente à *Aldeia da Serra* (primeira comunidade); o sol em dourado traz o calor da vizinhança e da confiança. O óculo da casa ecoa o sol — um detalhe que amarra a composição.

---

## 2. Logo

| Arquivo | Quando usar |
|---|---|
| `logo-horizontal.svg` | Uso principal: cabeçalhos, sites, assinaturas, materiais largos |
| `logo-stacked.svg` | Espaços quadrados/verticais: posts, splash, capas |
| `logo-icon.svg` | Avatar, favicon, app, marca-d'água — quando o nome já está claro no contexto |
| `logo-horizontal-reverse.svg` | Sobre fundos **escuros** (verde, foto escura) |
| `logo-icon-mono.svg` | Uma cor só: carimbo, gravação, fax, fundo claro |
| `app-icon.svg` / `app-icon-1024.png` | Ícone do aplicativo (full-bleed, o SO arredonda) |

### Área de proteção
Mantenha ao redor do logo um espaço livre equivalente à **altura da casa do ícone**. Nada (texto, foto, borda) deve invadir essa margem.

### Tamanho mínimo
- Ícone: **24 px** de altura (digital).
- Lockup horizontal: **120 px** de largura — abaixo disso, use só o ícone.

### Usos incorretos
- ❌ Não distorça nem altere a proporção.
- ❌ Não troque as cores fora da paleta.
- ❌ Não aplique sombra, contorno ou gradiente no logo.
- ❌ Não rotacione.
- ❌ Não use o lockup colorido sobre fundo escuro (use a versão *reverse*).
- ❌ Não recrie o wordmark em outra fonte.

---

## 3. Cores

A paleta vive em `mobile/lib/core/constants/app_colors.dart` — esta é a fonte da verdade.
Escala completa e racional de acessibilidade em [DESIGN_1.md](DESIGN_1.md).

**Verde foi removido do sistema por completo** (v1.1): a combinação anterior — verde
escuro + selo "veterano" marrom + erro vermelho — é quase o pior caso possível para
daltonismo vermelho-verde (~8% dos homens). Azul é o hue mais seguro entre todos os
tipos de daltonismo, base dos padrões Okabe-Ito e Wong.

### Primária — Azul Sereno

| Cor | Hex | Uso |
|---|---|---|
| 🔵 Azul Sereno (âncora) | `#2E5C74` | Cor da marca, AppBar, botões primários, selos |
| 🔵 Azul Sereno claro | `#78AFC0` | Ilustrações, estados leves |
| 🔵 Azul Sereno pressed | `#244A5D` | Estado pressed, serra de trás do logo |

### Secundária — Terracota

| Cor | Hex | Uso |
|---|---|---|
| 🟠 Terracota (âncora) | `#C97B4A` | Selo "Muito indicado", faixa "Bom" do Score, porta do logo, "Indica" |

### Apoio / Sistema

| Cor | Hex | Uso |
|---|---|---|
| Dourado | `#E3A83F` | Sol do logo, estrelas de avaliação — exclusivo |
| Carmim (erro) | `#B0223C` | Alertas, validação, ação de perigo |
| Roxo Neutro | `#5B4B8A` | Selo "Completo" |
| Grafite Quente | `#4A4038` | Selo "Veterano" |
| Superfície | `#F9FAFA` | Cards |
| Fundo | `#FFFFFF` | Telas, casa do logo |
| Texto Primário | `#1A1A1A` | Títulos e corpo |
| Texto Secundário | `#616261` | Legendas, tagline, hint |

**Sucesso não usa mais verde** — reatribuído para o próprio azul de marca (`#2E5C74`),
sempre acompanhado de ícone de check (nunca só a cor).

**Acessibilidade.** Azul Sereno `#2E5C74` sobre branco passa AA/AAA (7.24:1). Terracota
`#C97B4A` **não** tem contraste suficiente para texto branco (3.27:1) — use texto grafite
`#1A1A1A` por cima (5.32:1). Ver tabela completa de contraste em DESIGN_1.md.

---

## 4. Tipografia

| Papel | Fonte | Peso |
|---|---|---|
| Wordmark / títulos | **Poppins** | 700 (Bold) |
| Subtítulos | Poppins | 600 (SemiBold) |
| Corpo / interface | **Inter** | 400 / 500 |

Ambas são gratuitas (Google Fonts). Caso indisponíveis, o fallback é a sans-serif do sistema (`Segoe UI`, `Helvetica`, `Arial`).

No wordmark, **"Aldeia"** vai em Azul Sereno e **"Indica"** em Terracota — destacando a ação de recomendar.

---

## 5. Ícone do aplicativo

- Master: `app-icon-1024.png` (1024×1024, sem transparência).
- Full-bleed: fundo azul sereno preenche todo o quadrado; o iOS/Android aplica a máscara arredondada.
- Gerado automaticamente para iOS via `flutter_launcher_icons` (config no `pubspec.yaml`).
- Para regenerar após editar o master:
  ```bash
  cd mobile
  dart run flutter_launcher_icons
  ```

---

## 6. Tom de voz

- **Próximo, não corporativo.** "Encontre quem o seu vizinho já confia" > "Soluções em serviços".
- **Português do Brasil, direto.** Frases curtas.
- **Confiança no centro.** Reforce reputação, histórico e vizinhança.
- **Sem jargão técnico** para o usuário final.

Exemplos:
> ✅ "Maria, a diarista, tem Score 87 e 12 recomendações de vizinhos."
> ✅ "Fale com o prestador sem trocar telefone."
> ❌ "Onboarding de provider com KYC pendente."

---

## 7. Arquivos da marca

```
brand/
├── BRAND.md                          ← este guia (resumo de uso)
├── DESIGN_1.md                       ← design system completo v1.1 (tokens, racional)
├── aldeia_indica_manual_visual_1.html ← manual visual renderizado (abrir no navegador)
├── logo-horizontal.svg               ← uso principal
├── logo-stacked.svg                  ← vertical
├── logo-icon.svg                     ← só o ícone
├── logo-horizontal-reverse.svg       ← fundos escuros
├── logo-icon-mono.svg                ← 1 cor
├── app-icon.svg                      ← fonte do ícone do app
└── app-icon-1024.png                 ← master rasterizado 1024px
```

Os SVGs são a fonte da verdade — edite-os e re-exporte os PNGs quando necessário.
