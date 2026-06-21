# Aldeia Indica — Guia da Marca

> Rede de confiança comunitária para moradores e prestadores de serviços de bairros residenciais.

---

## 1. Essência

**Propósito.** Transformar as recomendações soltas dos grupos de WhatsApp em um histórico estruturado de confiança entre vizinhos e prestadores de serviço.

**Personalidade.** Acolhedora, confiável, local, vizinha. Não é um marketplace frio — é a praça do bairro em formato de app.

**Conceito do logo.** Uma **casa aninhada na serra, sob o sol nascente**. A casa é o lar e o pertencimento; a serra remete diretamente à *Aldeia da Serra* (primeira comunidade); o sol em âmbar traz o calor da vizinhança e da confiança. O óculo da casa ecoa o sol — um detalhe que amarra a composição.

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

### Primárias

| Cor | Hex | Uso |
|---|---|---|
| 🟢 Verde Floresta | `#1B5E20` | Cor da marca, fundos de destaque, botões primários |
| 🟢 Verde Claro | `#4CAF50` | Apoios, serra da frente, estados ativos |
| 🟢 Verde Escuro | `#003300` | Texto sobre verde claro, profundidade |

### Acento

| Cor | Hex | Uso |
|---|---|---|
| 🟠 Âmbar | `#F57F17` | Ação, "Indica", portas, chamadas |
| 🟡 Âmbar Claro | `#FFB300` | Sol, estrelas de avaliação, realces |

### Apoio / Sistema

| Cor | Hex | Uso |
|---|---|---|
| Azul Selo | `#0D47A1` | Badge do Score Aldeia |
| Sucesso | `#2E7D32` | Confirmações, serra de trás |
| Erro | `#B71C1C` | Alertas, validação |
| Superfície | `#F9FBF9` | Cards, casa do logo |
| Fundo | `#FFFFFF` | Telas |
| Texto Primário | `#1A1A1A` | Títulos e corpo |
| Texto Secundário | `#616161` | Legendas, tagline |

**Acessibilidade.** Verde Floresta `#1B5E20` sobre branco passa AA/AAA. Âmbar `#FFB300` **não** tem contraste suficiente para texto pequeno sobre branco — use-o como elemento gráfico ou com texto escuro por cima.

---

## 4. Tipografia

| Papel | Fonte | Peso |
|---|---|---|
| Wordmark / títulos | **Poppins** | 700 (Bold) |
| Subtítulos | Poppins | 600 (SemiBold) |
| Corpo / interface | **Inter** | 400 / 500 |

Ambas são gratuitas (Google Fonts). Caso indisponíveis, o fallback é a sans-serif do sistema (`Segoe UI`, `Helvetica`, `Arial`).

No wordmark, **"Aldeia"** vai em Verde Floresta e **"Indica"** em Âmbar — destacando a ação de recomendar.

---

## 5. Ícone do aplicativo

- Master: `app-icon-1024.png` (1024×1024, sem transparência).
- Full-bleed: fundo verde preenche todo o quadrado; o iOS/Android aplica a máscara arredondada.
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
├── BRAND.md                      ← este guia
├── logo-horizontal.svg           ← uso principal
├── logo-stacked.svg              ← vertical
├── logo-icon.svg                 ← só o ícone
├── logo-horizontal-reverse.svg   ← fundos escuros
├── logo-icon-mono.svg            ← 1 cor
├── app-icon.svg                  ← fonte do ícone do app
└── app-icon-1024.png             ← master rasterizado 1024px
```

Os SVGs são a fonte da verdade — edite-os e re-exporte os PNGs quando necessário.
