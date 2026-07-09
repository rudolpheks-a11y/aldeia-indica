# Product

## Register

product

## Users

Moradores e prestadores de serviço de bairros residenciais (começando pela Aldeia da Serra). Moradores buscam, avaliam e recomendam prestadores de confiança; prestadores cadastram suas habilidades, agenda e anúncios para serem encontrados. O público inclui faixa etária mais alta e usuários com menor familiaridade com apps — a interface precisa ser usável sem tutorial.

## Product Purpose

Rede de confiança comunitária: substitui a indicação boca-a-boca do bairro por um app que centraliza busca, avaliação, recomendação e contato direto (chat) entre moradores e prestadores da mesma comunidade. Sucesso é medido por confiança percebida (avaliações, selos, recomendações) e uso recorrente, não por engajamento de vaidade.

## Brand Personality

Acolhedor, confiável, de vizinhança — não corporativo, não parece um marketplace genérico tipo Uber/iFood. Tom de bairro: Azul Sereno + Terracota (paleta v1.1, daltonismo-safe — fonte da verdade em `brand/DESIGN_1.md` e `mobile/lib/core/constants/app_colors.dart`), calor humano acima de polimento de SaaS. Dourado é reservado a estrelas e destaques, sempre com conteúdo grafite (nunca branco — 2.11:1).

**Tema:** claro, único e intencional. Não há dark mode por decisão de produto (2026-07-08): o público de faixa etária mais alta se beneficia de uma aparência única e previsível, e o custo de manter duas paletas com contraste validado não se paga nesta fase. Reavaliar apenas se houver pedido recorrente de usuários reais.

## Anti-references

- Marketplaces genéricos frios (Uber, iFood, apps de gig economy) — sensação transacional, não comunitária.
- Dashboards SaaS corporativos (cinza-sobre-branco, densidade de dados, jargão de produto).
- Qualquer sofisticação visual que sacrifique clareza (animações complexas, hierarquia confusa, texto pequeno).

## Design Principles

1. **Clareza acima de sofisticação** — o usuário pode ter baixo letramento digital; nunca escolher elegância visual em troca de compreensão imediata.
2. **Vizinhança, não vitrine** — cada tela deve parecer uma conversa de bairro, não uma vitrine de produto.
3. **Confiança é visível, não abstrata** — selos, avaliações e recomendações precisam ser lidos rapidamente e sem ambiguidade.
4. **Toque grande, contraste alto** — otimizar para uso real por faixa etária mais alta, não para densidade de informação.
5. **Consistência com o que já existe** — paleta (`app_colors.dart`) e componentes já commitados são a base; não reinventar sem motivo forte.

## Accessibility & Inclusion

Público inclui usuários mais velhos e com baixo letramento digital. Priorizar: contraste alto (corpo de texto ≥4.5:1, preferir mais escuro que o mínimo), áreas de toque grandes, textos claros sem jargão, mínimo de gestos complexos, WCAG AA como piso.
