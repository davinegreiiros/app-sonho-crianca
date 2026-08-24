# Tasks: Migração — Locação ativa, estender, cancelar, encerrar + Pix

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `RentalRepository.extend`/`finish`; `AppState.extendActive`/`confirmEnd` refatorados por dentro.
- [x] T2 — `ActiveRentalsState` (Equatable) + `ActiveRentalsCubit` em `lib/ui/features/rental/view_models/`.
- [x] T3 — `ActiveTabView` em `lib/ui/features/rental/views/` — mover UI de `active_tab.dart`, `fmtClock`/`statusColor`/`pulseOnOvertime` viram locais.
- [x] T4 — `EndRentalDialogView` — mover UI de `end_rental_dialog.dart`, checagem de Pix lê `BusinessSettingsCubit`.
- [x] T5 — `PixQrSheetView` — mover UI de `pix_qr_sheet.dart`.
- [x] T6 — `home_shell.dart`/`modal_launchers.dart`/`main.dart` atualizados. Removidos `active_tab.dart`/`end_rental_dialog.dart`/`pix_qr_sheet.dart`.
- [x] T7 — `AppState.fmtClock`/`statusColor`/`pulseOnOvertime` removidos.
- [x] T8 — `test/extend_time_widget_test.dart`: tempo de pump ajustado (ticker novo), nenhum `expect` mudou.
- [x] T9 — `test/active_rentals_cubit_test.dart`: `RentalRepository.extend`/`finish`, `ActiveRentalsCubit` (extend, cancel, fluxo de encerrar, Pix, sincronia com `AppState`) — achado um bug de aliasing no próprio teste (não no código) durante a escrita, corrigido.
- [x] T10 — `flutter analyze` limpo.
- [x] T11 — `flutter test` completo, sem alterar nenhum assert existente (88 testes — 79 anteriores + 9 novos —, todos verdes; `test/pix_flow_test.dart` intacto, sem nenhuma mudança).
- [x] T12 — Revisão manual dos critérios de aceite do `spec.md` + atualizar `specs/README.md` (linha 018 vira `Implemented`).

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
