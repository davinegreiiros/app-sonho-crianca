# Inventário de componentes — Sonho de Criança

Todo widget reutilizável hoje em `lib/widgets/`, o que faz e onde é usado. Feature nova reusa daqui antes de criar componente novo.

## Estrutura / navegação

| Componente | Arquivo | O que é | Usado em |
|---|---|---|---|
| `HomeShell` | `screens/home_shell.dart` | scaffold: header + corpo por aba + bottom nav + FAB | `main.dart` (raiz do app) |
| `AppHeader` | `widgets/app_header.dart` | header com gradiente, logo, kicker de local/data, título da tela, 3 pontos animados | `HomeShell` |
| `AppBottomNav` | `widgets/app_bottom_nav.dart` | barra de 4 abas custom (não é `BottomNavigationBar` padrão) | `HomeShell` |

## Cards e conteúdo

| Componente | Arquivo | O que é | Usado em |
|---|---|---|---|
| `_ToyCard` (privado) | `screens/tabs/catalog_tab.dart` | card de brinquedo: imagem, tag de disponibilidade, campos de preço/minutos editáveis | `CatalogTab` |
| `_ActiveCard` (privado) | `screens/tabs/active_tab.dart` | card de locação ativa: ícone, nome, contador regressivo, progresso, botões cancelar/finalizar | `ActiveTab` |
| `ToyIcon` | `widgets/toy_icon.dart` | ilustração `assets/images/toy-<key>.png` sobre fundo tintado, com fallback de ícone genérico | `_ToyCard`, `_ActiveCard`, picker de ícone do `AddToySheet` |
| `_MiniField` (privado) | `screens/tabs/catalog_tab.dart` | input numérico compacto com rótulo, usado pra editar preço/minutos direto no card | `_ToyCard` |

## Modais e sheets

| Componente | Arquivo | O que é | Lançado por |
|---|---|---|---|
| `NewRentalSheet` | `widgets/new_rental_sheet.dart` | bottom sheet "Nova locação": brinquedo, criança, responsável, telefone, duração, valor | `showNewRentalSheet` (`modal_launchers.dart`), FAB |
| `EndRentalDialog` | `widgets/end_rental_dialog.dart` | dialog central "Finalizar locação": resumo + escolha de forma de pagamento | `showEndRentalDialog` (`modal_launchers.dart`), botão "Finalizar" do `_ActiveCard` |
| `AddToySheet` | `widgets/add_toy_sheet.dart` | bottom sheet "Novo brinquedo": nome, grade de ícones, quantidade/preço/minutos, cor | `showAddToySheet` (`modal_launchers.dart`), botão "Adicionar brinquedo" do `CatalogTab` |
| `modal_launchers.dart` | `widgets/modal_launchers.dart` | funções `showX(context)` centralizando `showModalBottomSheet`/`showDialog` — ponto único de abertura de overlay | chamado pelas telas acima |

## Motion (ver também `design-tokens.md`)

| Componente | Arquivo | O que é |
|---|---|---|
| `Bouncy` | `widgets/animations/bounce.dart` | bounce vertical contínuo, com fase pra escalonar múltiplas instâncias |
| `Pressable` | `widgets/animations/pressable.dart` | feedback de press/hover (scale + rotação opcional), não intercepta o gesto do filho |
| `CascadeController` | `widgets/animations/cascade.dart` | orquestra entrada escalonada de itens de lista/grid (fade+slide ou pop elástico) |
| `StripedProgress` | `widgets/animations/striped_progress.dart` | barra de progresso "barbeiro" com pulso de overtime |
| `PrintStrip` | `widgets/animations/print_strip.dart` | faixa tricolor CMY com reveal de largura animado |
| `FloatingConfetti` | `widgets/animations/confetti.dart` | partículas decorativas flutuando, ignora toque |

## Tema

| Componente | Arquivo | O que é |
|---|---|---|
| `AppColors` | `theme/app_colors.dart` | paleta central + enum `ToyInk` (tint/fg/dot por categoria de cor de brinquedo) |
| `AppTheme` | `theme/app_theme.dart` | `ThemeData` global: Source Serif 4, cores base, sem splash/highlight padrão do Material |

## Padrões observados (pra features novas seguirem)

- Todo botão/ícone tocável é envolvido em `Pressable`.
- Toda lista/grid que aparece de uma vez usa `CascadeController` pra entrada escalonada — não aparece "seco".
- Toda tag/pill de status reusa o par tint/fg do `ToyInk` do brinquedo dono do card (nunca uma cor solta nova).
- Abertura de modal/sheet sempre passa por `modal_launchers.dart` — nunca `showModalBottomSheet`/`showDialog` chamado direto de dentro de uma tela/tab.
- Toda tela com campos numéricos (preço, minutos, quantidade) valida antes de habilitar o botão de ação — nunca deixa submeter estado inválido.
