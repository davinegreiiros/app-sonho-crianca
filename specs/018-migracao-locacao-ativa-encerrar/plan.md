# Plan: Migração — Locação ativa, estender, cancelar, encerrar + Pix

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

1. **`RentalRepository.extend`/`finish`** — mutam campos do `Rental` (mesmo objeto, já mutável) e chamam `notifyListeners()`, diferente de `add`/`removeById` que também mudam a estrutura da lista. Corrige a lacuna de notificação descrita no `spec.md`.
2. **`AppState.extendActive`**: em vez de mutar `r.durationMin`/`r.price` direto, calcula os novos valores e chama `_rentalRepository.extend(id, durationMin: ..., price: ...)`. **`AppState.confirmEnd`**: calcula `finalPrice` (só se `isOpenEnded`) e chama `_rentalRepository.finish(endingId!, endPayment!, finalPrice: ...)`. Mesma saída, mesmos testes cobrindo.
3. **`ActiveRentalsState`** — `activeRentals: List<Rental>`, `endingId`, `endPayment`, `endShowPixQr`, `endFrozenPrice`, mais um getter `endingRental` (procura em `activeRentals` — como visto no `spec.md`, `endingId` já vira `null` na mesma notificação que finaliza a locação, não existe frame intermediário onde diverge do original, que procurava em `rentals` completo).
4. **`ActiveRentalsCubit`** — injeta `ToyRepository` (pra `toyById`/`ratePerMinute`/`computeFinalPrice`) + `RentalRepository` + `RentalNotifier?` opcional + `ScheduleRentalEndNotifications` (reusa a da 017). Ticker de 1s próprio (`Timer.periodic`) recalcula `activeRentals` a cada segundo — mesmo papel do `_ticker` de `AppState`, necessário pros cronômetros/alarme de tempo esgotado atualizarem sozinhos. `extendActive`/`cancelActive`/`confirmEnd` chamam os métodos novos do Repository; `openEnd`/`closeEnd`/`selectPayment`/`showPixQrStep`/`hidePixQrStep` só mexem no estado próprio do diálogo (sem tocar `RentalRepository`).
5. **Views**: `ActiveTabView` (mesmo `_ActiveCard`/`_ExtendTimeRow`/etc., trocando `AppState` por `ActiveRentalsCubit`; `fmtClock`/`statusColor`/`_pulseOnOvertime` viram funções/consts privadas do arquivo — só esse consumidor existia). `EndRentalDialogView` troca `state.rentals`/`endingId`/etc. por `context.watch<ActiveRentalsCubit>()`; a checagem `businessSettings.isConfigured` lê `context.read<BusinessSettingsCubit>().state.settings`. `PixQrSheetView` mesma troca, mais `context.read<BusinessSettingsCubit>()` pro payload.
6. **`modal_launchers.dart`**: `showEndRentalDialog` guarda `context.read<ActiveRentalsCubit>()` antes do `await` (mesmo padrão de hoje com `AppState`), chama `.openEnd(rentalId)`/`.closeEnd()`.
7. **`main.dart`**: `BlocProvider<ActiveRentalsCubit>` novo.
8. Remove `lib/screens/tabs/active_tab.dart`, `lib/widgets/end_rental_dialog.dart`, `lib/widgets/pix_qr_sheet.dart`.
9. **`test/extend_time_widget_test.dart`**: o truque `state.setTab(state.tab); await tester.pump(400ms)` pra forçar rebuild não alcança mais o Cubit novo (que só escuta `RentalRepository` + seu próprio ticker de 1s). Troca pra só `await tester.pump(const Duration(milliseconds: 1100))` (deixa o ticker novo disparar) — mudança de tempo de pump, nenhum `expect` muda.

## Arquivos afetados

- `lib/data/repositories/rental_repository.dart` — ganha `extend`/`finish`.
- `lib/state/app_state.dart` — `extendActive`/`confirmEnd` refatorados por dentro; `fmtClock`/`statusColor`/`pulseOnOvertime`/`_alertColor`/`_pulseOnOvertime` removidos.
- `lib/ui/features/rental/view_models/active_rentals_state.dart` — novo.
- `lib/ui/features/rental/view_models/active_rentals_cubit.dart` — novo.
- `lib/ui/features/rental/views/active_tab_view.dart` — novo (movido de `active_tab.dart`).
- `lib/ui/features/rental/views/end_rental_dialog_view.dart` — novo (movido de `end_rental_dialog.dart`).
- `lib/ui/features/rental/views/pix_qr_sheet_view.dart` — novo (movido de `pix_qr_sheet.dart`).
- `lib/screens/tabs/active_tab.dart`, `lib/widgets/end_rental_dialog.dart`, `lib/widgets/pix_qr_sheet.dart` — removidos.
- `lib/screens/home_shell.dart`, `lib/widgets/modal_launchers.dart`, `lib/main.dart` — atualizados.
- `test/extend_time_widget_test.dart` — ajuste de tempo de pump (ver acima).
- `test/active_rentals_cubit_test.dart` — novo.

## Modelo de dados / estado

`ActiveRentalsState` novo (Equatable). Nenhum domain model muda.

## Riscos / dependências

- Maior risco: `test/pix_flow_test.dart` — dirige tudo via UI (`TestKeys`), nenhuma chamada direta a `AppState`. Se `ActiveTabView`/`EndRentalDialogView`/`PixQrSheetView` reproduzirem o comportamento fielmente, passa sem mudança nenhuma — é o teste de fumaça mais importante desta fatia.
- `RentalRepository.extend`/`finish` mudam o *timing* de quando `RentalRepository` notifica (antes: nunca, pra essas duas operações; agora: sempre) — isso é uma correção de bug, não uma regressão, mas amplia quem reage a essas mudanças (Report/Catálogo). Nenhum teste existente depende do comportamento antigo (a lacuna nunca foi testada, porque nada dependia dela ainda).
- Depende de 013 (`RentalRepository`), 015 (`ToyCatalogCubit`/`ComputeToyAvailability`), 016 (Services), 017 (`ScheduleRentalEndNotifications`, padrão de Cubit com estado de UI próprio).

## Alternativas consideradas

- **Sub-fatiar ainda mais (ativa/estender/cancelar separado de encerrar/Pix).** Descartado — os dois fluxos compartilham a mesma máquina de estado do diálogo (`endingId`/`endPayment`/`endShowPixQr`/`endFrozenPrice`); separar duplicaria esse estado ou forçaria uma dependência entre duas fatias no meio da implementação, aumentando risco em vez de reduzir.
- **Deixar a lacuna de notificação do `RentalRepository` como está.** Descartado — já que a fatia está mexendo exatamente nesse código (`extendActive`/`confirmEnd`), corrigir agora é mais barato que descobrir e corrigir depois como um bug separado.
