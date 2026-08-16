# Design tokens — Sonho de Criança

Fonte única de verdade de token visual. Toda spec nova (`003`–`006`) reusa daqui — nenhuma cor/raio/espaçamento/motion novo sem passar por este documento primeiro.

## Cor

Definidas em [lib/theme/app_colors.dart](../../lib/theme/app_colors.dart).

| Token | Valor | Uso |
|---|---|---|
| `AppColors.bg` | `#F3F2F2` | fundo geral do app |
| `AppColors.surface` | `#EAE9E9` | fundo de input/card secundário |
| `AppColors.text` | `#201E1D` | texto padrão |
| `AppColors.accent` | `#0088B0` (ciano) | cor primária — botões, foco |
| `AppColors.accent2` | `#D6006C` (magenta) | cor secundária — FAB, acento |
| `AppColors.divider` | `#201E1D` a 16% | linhas divisórias |
| `AppColors.processYellow` | `#EDBB00` | terceira cor do trio CMY, decorativo |
| `AppColors.overlayScrim` | `#2D2B2B` | véu de fundo de modal |
| `AppColors.statusOk` / `statusWarn` / `statusUrgent` | verde `#2F7D52` / âmbar `#B98900` / âmbar escuro `#946B00` | cor do contador de locação por faixa de tempo restante (`AppState.statusColor`, `app_state.dart:103`) |
| Ramp ciano | `accent100` `#E9F8FF`, `accent200` `#CBEEFF`, `accent700` `#006786`, `accent900` `#0A303E` | tint/fg de brinquedo `ToyInk.cyan`, gradiente do header |
| Ramp magenta | `accent2_100` `#FFF1F4`, `accent2_200` `#FFDEE6`, `accent2_700` `#AA0B56`, `accent2_900` `#4B1528` | tint/fg de brinquedo `ToyInk.magenta` |
| `yellowTint`/`yellowFg`/`yellowFgDark` | `#F5E9C2` / `#7A5F00` / `#4A3A00` | tint/fg de brinquedo `ToyInk.yellow` |
| Logo | `logoPink` `#E83E8C`, `logoOrange` `#FF8A3D`, `logoYellow` `#FFC93D` | gradiente do marca-d'água "SC" no header |

**Regra:** toda cor nova é derivada de uma dessas — nunca um hex solto num widget. `ToyInk` (`app_colors.dart:60`) já é o padrão de "3 tons por categoria" (tint/fg/dot) — qualquer tag/chip nova (ex: tipo de brinquedo em `003`) reusa esse mesmo padrão de 3 tons, não inventa um quarto esquema de cor.

## Tipografia

Fonte: `google_fonts` Source Serif 4, aplicada globalmente em [lib/theme/app_theme.dart:22](../../lib/theme/app_theme.dart#L22) via `GoogleFonts.sourceSerif4TextTheme`. Cor de texto/display fixada em `AppColors.text`.

Tamanhos em uso hoje (não há escala nomeada formal — inventário do que existe):

| Tamanho | Peso | Onde |
|---|---|---|
| 27 | 600 | título de tela no header (`app_header.dart:75`) |
| 22 | 700 | título de sheet (`AddToySheet`, `add_toy_sheet.dart:81`) |
| 19 | 600 | título de sheet (`NewRentalSheet`, `new_rental_sheet.dart:39`) |
| 18 | 600 | título de dialog (`EndRentalDialog`, `end_rental_dialog.dart:59`) |
| 15 | 800 / 600 | nome da marca no header / nome de brinquedo em card ativo |
| 13–14 | 600 | corpo de botão, texto de card |
| 9.5–12 | 600 | rótulo pequeno / tag / kicker |

**Gap conhecido:** essa escala não está nomeada (`headline`, `title`, `label`...) em nenhum lugar central — é ad-hoc por widget. Não é bug, mas qualquer feature nova (`003`–`006`) que precise de um tamanho de texto deve reusar um dos valores acima em vez de escolher um número novo.

## Espaçamento e raio

Sem token central (`AppSpacing`/`AppRadius` não existem) — em uso consistente por convenção:

| Valor | Uso |
|---|---|
| `4 / 8 / 10 / 12 / 14 / 16 / 20` | gaps verticais/horizontais entre elementos, escala de 2px sobre base par |
| raio `2 / 3 / 4` | inputs, botões, tags, cards de lista (elementos "de trabalho") |
| raio `6 / 8` | cards maiores, sheets, modal (`EndRentalDialog`, `AddToySheet`) |
| raio `16` | topo de bottom sheet (`NewRentalSheet`, `AddToySheet`) |

**Regra pra `003` (tickets):** ticket novo usa raio da família "elementos de trabalho" (2–4), não 6/8 — é um elemento pequeno dentro do card, não um container próprio.

## Motion

Definidos em [lib/widgets/animations/](../../lib/widgets/animations/). Todos com `vsync` próprio, nenhum usa `pumpAndSettle`-hostil sem motivo (ver comentário em `integration_test/app_test.dart:11`).

| Componente | Duração | Curva | Efeito | Uso |
|---|---|---|---|---|
| `Bouncy` | 1200ms, loop reverse | `easeInOut` | translação vertical −4px | FAB, 3 pontos do header (`app_header.dart:82-86`, com `phase` escalonado) |
| `Pressable` | 110ms (scale) / 150ms (rotate) | `easeOut` | scale 0.96 no press, 1.02 no hover, rotação opcional | qualquer botão/ícone tocável |
| `CascadeController` | 55ms de stagger por item, 380ms por item | `easeOutCubic` (fade+slide) ou `easeOutBack` (pop) | entrada escalonada de lista/grid | grade do catálogo (pop), lista de locações ativas |
| `StripedProgress` | listra 900ms loop, pulse 1100ms loop reverse | linear (listra), implícita (pulse) | barra "barbeiro" diagonal + pulso de opacidade em overtime | progresso de locação ativa |
| `PrintStrip` | 550ms | `easeOutCubic` | largura crescendo da esquerda pra direita | faixa tricolor CMY no header e no topo das sheets |
| `FloatingConfetti` | 6000ms loop | linear com fade nas pontas | partículas CMY subindo | decorativo sobre o card "faturado hoje" (`home_tab.dart:173`) |

**Regra:** feature nova que precisa de "aparecer com graça" reusa `CascadeController`; feedback de toque reusa `Pressable`; nenhuma spec cria um novo `AnimationController` solto pra algo que já tem componente aqui.
