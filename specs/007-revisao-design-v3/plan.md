# Plan: Revisão de Design v3

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Cada artboard (1a–1e) vira uma mudança isolada em componente já existente — nenhuma tela nova de fluxo, só um novo `Navigator.push` pra Configurações. Ícones de categoria usam `flutter_svg` (dependência nova) renderizando paths Phosphor extraídos 1:1 do `.dc.html` como `currentColor` (tint via `ColorFilter`), então uma única cor tinge preenchimento (opacity 0.25) e traço, igual ao design.

Fonte do design salva em `specs/_design-source/Revisao de Design v3.dc.html` (referência, não compilado no app).

## Arquivos afetados

- `pubspec.yaml` — nova dependência `flutter_svg`; novo asset dir `assets/icons/category/`.
- `assets/icons/category/*.svg` — novo: 6 ícones Phosphor duotone (eletrico, inflavel, passeio, aquatico, radiocontrole, outro), `currentColor` + `fill-opacity`/paths conforme design.
- `lib/models/toy.dart` — `ToyCategory` ganha extension `icon` (asset path) e `ink` (cor de tinta fixa da categoria — distinta do `ToyInk` do brinquedo).
- `lib/theme/app_colors.dart` — cor neutra "Outro" (`#605d5d` fg / `#eae9e9` bg) se ainda não coberta por token existente.
- `lib/widgets/category_icon.dart` — novo: widget pequeno que resolve `SvgPicture.asset` + `ColorFilter` pra uma categoria.
- `lib/screens/tabs/catalog_tab.dart` — `_Tag` ganha ícone; `_TicketStub` ganha retícula (halftone) via `CustomPainter` quando livre, contorno 45% quando em uso.
- `lib/widgets/add_toy_sheet.dart` — `_CategoryPicker` chips ganham ícone.
- `lib/services/pix_payload.dart` — `buildPixPayload` já aceita `txid`; sem mudança de assinatura, só quem chama passa um valor real.
- `lib/widgets/pix_qr_sheet.dart` — reescrito: moldura de cupom (serrilha topo/base via `CustomPainter` ou `ShapeBorder`, faixa CMY, kicker "Cobrança Pix" + doc), estado "Aguardando confirmação" (pulsa via `AnimatedOpacity`/`Tween` já usado em `Bouncy`/`StripedProgress`), botão "Trocar forma".
- `lib/state/app_state.dart` — novo método `backToPaymentMethod()` (ou reaproveitar `endShowPixQr = false` num setter público) pra "Trocar forma"; `endFrozenPrice` reseta igual ao fluxo de cancelar.
- `lib/widgets/business_settings_sheet.dart` → renomeado/movido pra `lib/screens/business_settings_screen.dart` (`BusinessSettingsScreen`, full-page, `Scaffold` com header ao estilo `AppHeader` + botão voltar "Painel"); mini-preview de QR ao lado da chave.
- `lib/widgets/modal_launchers.dart` — `showBusinessSettingsSheet` vira `openBusinessSettingsScreen` usando `Navigator.push(MaterialPageRoute(...))`.
- `lib/widgets/app_header.dart` — gear icon chama `openBusinessSettingsScreen`.
- `lib/widgets/end_rental_dialog.dart` — hint de Pix não configurado chama `openBusinessSettingsScreen` no lugar do sheet.
- `lib/screens/tabs/active_tab.dart` — branch `openEnded`: troca clock color pra magenta (`AppColors.accent2_700`), troca `StripedProgress` (que hoje só roda quando `!openEnded`) por um trilho tracejado "sem fim" novo, adiciona bloco "Estimado agora", troca texto do botão de finalizar pra "Parar e cobrar" quando `openEnded`.
- `lib/widgets/animations/` — possível novo `EndlessRail` (trilho tracejado que desliza, mask no fim) reaproveitando o padrão de `AnimationController` já usado em `StripedProgress`.
- `lib/test_keys.dart` — chaves novas: `categoryIcon` (se precisar de key própria — provável não, ícone é decorativo dentro do pill/chip já com key), `pixTrocarFormaButton`, `pixWaitingIndicator` (se testável), `settingsScreenBackButton`.
- `test/` — cobertura nova/ajustada pros critérios de aceite (ícone de categoria, canhoto livre/em uso, CTA "Parar e cobrar"); ajustar testes existentes que hoje abrem Configurações via `showModalBottomSheet` pra usar `Navigator.push`.

## Modelo de dados / estado

- `ToyCategory` (enum existente, sem novo valor) ganha duas extensions novas: `icon` (String asset path) e `ink` (cor de tinta fixa — não confundir com `ToyInk` do brinquedo, que continua CMY por brinquedo individual).
- `AppState`: `endShowPixQr` continua bool; adiciona forma pública de voltar pra `false` sem passar por `closeEnd()` (que reseta tudo). Sem novo campo persistido — nada disso é dado sensível novo.
- `BusinessSettings`/persistência via `shared_preferences`: inalterado.

## Riscos / dependências

- `flutter_svg` é dependência nova — checar que não conflita com `flutter_launcher_icons`/SDK constraints do `pubspec.yaml` (`flutter: "3.44.6"`). Rodar `flutter pub get` logo após editar.
- Mover Configurações de sheet pra tela cheia pode quebrar testes existentes que esperam `showModalBottomSheet` (regra de não-quebra da constitution) — ajustar os testes na mesma task, não depois.
- QR com olhos multicoloridos não é suportado por `qr_flutter` — mantido monocromático (já documentado em spec.md como desvio intencional, não é regressão).
- "Aguardando confirmação" é só visual — não pode virar promessa implícita de verificação automática; texto e comentário no código deixam isso explícito.
- **Aprendido durante a implementação:** um `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` em volta de um `Pressable(child: SizedBox(height: N, child: ElevatedButton(...)))` ao lado de um `Expanded` com conteúdo multi-linha fez `WidgetTester.tap` falhar intermitentemente com "Cannot hit test a render box with no size" no `pixQrDoneButton`, mesmo sem relação direta de código entre os dois widgets — bisecção confirmou (contagem de exceções caiu de 86 pra 46 pra 0 removendo peça por peça). Corrigido revertendo o botão "Copiar" pro padrão `Pressable(TextButton.icon(...))` sem `SizedBox`/stretch, que já era usado em todo o resto do app. Não reintroduzir essa combinação.

## Alternativas consideradas

- Ícones de categoria como `CustomPainter` desenhado à mão (sem nova dependência): descartado — mais trabalho pra manter fidelidade aos 6 paths do Phosphor, e projeto já usa só assets/pacotes simples (`google_fonts`, `qr_flutter`) então mais uma dependência de renderização (SVG) é consistente com o padrão.
- Configurações como rota nomeada (`onGenerateRoute`): descartado — app não tem tabela de rotas em nenhum outro lugar; `Navigator.push` direto é o mínimo necessário e não muda a arquitetura de navegação do resto do app.
