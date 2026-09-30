# Spec: Migração — Locação ativa, estender, cancelar, encerrar + Pix

Status: Implemented
Criado: 2026-08-24

Sub-fatia do roadmap 018+ (ver "Aprendizado da fatia 016"/017 em [specs/010-migracao-arquitetura-camadas](../010-migracao-arquitetura-camadas/spec.md)). Migra `active_tab.dart` + `end_rental_dialog.dart` + `pix_qr_sheet.dart` juntos — os três compartilham uma única máquina de estado do diálogo de encerramento (`endingId`/`endPayment`/`endShowPixQr`/`endFrozenPrice`), separar mais fragmentaria isso sem reduzir risco. `home_tab.dart` fica pra fatia seguinte.

## Problema

`active_tab.dart`, `end_rental_dialog.dart` e `pix_qr_sheet.dart` leem/gravam em `AppState`: `activeRentals`, `extendActive`, `cancelActive`, `openEnd`/`closeEnd`, `selectPayment`, `showPixQrStep`/`hidePixQrStep`, `confirmEnd`, `computeFinalPrice`, `businessSettings`, `toyById`, `fmtClock`/`statusColor`/`pulseOnOvertime`/`fmtMoney`.

Mesma situação da 017: `extendActive`/`cancelActive`/`openEnd`/`closeEnd`/`selectPayment`/`showPixQrStep`/`confirmEnd`/`computeFinalPrice` são chamados **diretamente** por `extend_rental_test.dart`, `open_ended_rental_test.dart`, `rental_notifications_test.dart` — continuam existindo, mesma assinatura.

**Achado no processo**: `RentalRepository.finish()`/`extend()` (novos, ver Objetivo) corrigem uma lacuna que a fatia 013 introduziu sem querer — `AppState.extendActive`/`confirmEnd` mutavam um `Rental` já na lista diretamente (campo a campo) e só chamavam `notifyListeners()` em si mesmos, nunca em `RentalRepository`. Isso significa que hoje, estender/encerrar uma locação pelo mundo antigo não notifica `ReportCubit`/`ToyCatalogCubit` (que escutam `RentalRepository`) — eles só atualizam na próxima mudança estrutural (nova locação, cancelamento). Corrigido nesta fatia pra todo mundo, não só pro Cubit novo.

## Objetivo

`active_tab.dart` + `end_rental_dialog.dart` + `pix_qr_sheet.dart` viram `ActiveRentalsCubit` + `ActiveTabView` + `EndRentalDialogView` + `PixQrSheetView` (`lib/ui/features/rental/`), com sua própria máquina de estado do diálogo de encerramento (independente da de `AppState` — mesmo raciocínio da 017: é estado de UI efêmero). `RentalRepository` ganha `extend(...)`/`finish(...)` — mutam e notificam — usados tanto pelo `ActiveRentalsCubit` quanto (refatoração interna) por `AppState.extendActive`/`confirmEnd`.

A checagem "Pix sem configurações → manda pra tela de config" continua na View (mesmo lugar de hoje), lendo `BusinessSettingsCubit` via `context` em vez de `AppState.businessSettings`.

## Fora de escopo

- `home_tab.dart` — próxima fatia.
- Qualquer mudança de comportamento visível.
- `fmtClock`/`statusColor`/`pulseOnOvertime` (só usados por `active_tab.dart` — confirmado por grep) somem de `AppState` (ninguém mais os chama) e viram funções/consts locais da nova View, não um Use Case/Service novo — é lógica de apresentação pura (deriva `Color`/string pra tela), não pertence a `domain/`.

## Cenários de usuário

Paridade total:

1. Dado locações ativas (fixas e tempo corrido), quando o operador abre "Em andamento", então vê os mesmos cards, cronômetros, cores de status e alarme de tempo esgotado de hoje.
2. Dado uma locação de duração fixa ativa, quando o operador toca "+10min" (etc.), então duração/preço atualizam e as notificações são reagendadas — e agora `ReportCubit`/`ToyCatalogCubit` também ficam cientes da mudança (correção da lacuna descrita acima).
3. Dado uma locação ativa, quando o operador cancela, então ela some da lista — refletido também no catálogo/relatório (já valia antes, `removeById` já notificava certo).
4. Dado uma locação ativa, quando o operador finaliza escolhendo Cartão/Dinheiro, então ela vira "done" imediatamente; escolhendo Pix sem configuração, é redirecionado pra Configurações; com configuração, vê o QR e só finaliza ao confirmar "Recebido, concluir" — mesmo comportamento de hoje (coberto por `test/pix_flow_test.dart`, que dirige tudo via `TestKeys`, sem chamar `AppState` direto — deve passar sem nenhuma mudança).

## Critérios de aceite

- [x] `RentalRepository.extend(rentalId, {durationMin, price})` e `RentalRepository.finish(rentalId, method, {finalPrice})` — mutam o `Rental` e chamam `notifyListeners()` (corrige a lacuna descrita no Problema).
- [x] `AppState.extendActive`/`confirmEnd` passam a usar esses métodos por dentro — mesma assinatura pública, mesmo resultado (coberto por `extend_rental_test.dart`, `open_ended_rental_test.dart`, `rental_notifications_test.dart`, que chamam esses métodos direto).
- [x] `ActiveRentalsCubit` + `ActiveRentalsState` (`lib/ui/features/rental/view_models/`) — `activeRentals` (derivado de `RentalRepository`, recalculado por um ticker de 1s próprio, igual o de `AppState`), estado do diálogo de encerramento próprio, `extendActive`/`cancelActive`/`openEnd`/`closeEnd`/`selectPayment`/`showPixQrStep`/`hidePixQrStep`/`confirmEnd`/`computeFinalPrice`/`toyById`/`ratePerMinute`.
- [x] `ActiveTabView`, `EndRentalDialogView`, `PixQrSheetView` (`lib/ui/features/rental/views/`) substituem `active_tab.dart`/`end_rental_dialog.dart`/`pix_qr_sheet.dart` — mesmo layout, mesmas `TestKeys`. A checagem de Pix sem configuração lê `BusinessSettingsCubit`.
- [x] `home_shell.dart` aponta pra `ActiveTabView`; `modal_launchers.dart` (`showEndRentalDialog`) usa `ActiveRentalsCubit`/`EndRentalDialogView`.
- [x] `AppState.activeRentals`/`extendActive`/`cancelActive`/`openEnd`/`closeEnd`/`selectPayment`/`showPixQrStep`/`hidePixQrStep`/`confirmEnd`/`computeFinalPrice`/`endingId`/`endPayment`/`endShowPixQr`/`endFrozenPrice` continuam com a mesma assinatura pública.
- [x] `AppState.fmtClock`/`statusColor`/`pulseOnOvertime` removidos (sem outro consumidor).
- [x] `main.dart` registra `BlocProvider<ActiveRentalsCubit>`.
- [x] Teste novo (unit, sem `WidgetTester`) cobrindo `RentalRepository.extend`/`finish` e `ActiveRentalsCubit`.
- [x] `flutter analyze` limpo.
- [x] Toda a suíte de testes existente passa (88 testes, todos verdes) — `pix_flow_test.dart` (dirige tudo via UI) não precisou de nenhuma mudança; `extend_rental_test.dart`, `open_ended_rental_test.dart`, `rental_notifications_test.dart`, `design_v3_test.dart` intactos. `extend_time_widget_test.dart`'s truque de "notifyListeners via `state.setTab(state.tab)` + pump 400ms" foi trocado por um pump de 1100ms (deixa o ticker novo do `ActiveRentalsCubit` disparar) — nenhum `expect` mudou.

## Requisitos não-funcionais

- `RentalRepository.extend`/`finish` e `ActiveRentalsCubit` testáveis com `flutter_test` puro.

## Dúvidas em aberto

Nenhuma bloqueante.
