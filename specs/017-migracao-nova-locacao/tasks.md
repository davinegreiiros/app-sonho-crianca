# Tasks: Migração — Nova locação

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — Movido `lib/ui/core/formatters.dart` → `lib/domain/formatters.dart`; imports atualizados em `app_state.dart`/`report_view.dart`. Bônus (mesmo motivo): `lib/data/services/rental_notifier.dart` e `notification_texts.dart` também movidos pra `lib/domain/` (só `local_rental_notifier.dart`, a implementação real, ficou em `data/services/`).
- [x] T2 — `ScheduleRentalEndNotifications` em `lib/domain/use_cases/`; `AppState._scheduleEndNotification` delega pra ele.
- [x] T3 — `RentalRepository.addNew(...)`; `AppState.submitNew()` passa a usar.
- [x] T4 — `NewRentalState` (Equatable) + `NewRentalCubit` em `lib/ui/features/rental/view_models/`.
- [x] T5 — `NewRentalSheetView` em `lib/ui/features/rental/views/` — mover UI de `new_rental_sheet.dart`, trocar `AppState` por `NewRentalCubit`.
- [x] T6 — `modal_launchers.dart`: `showNewRentalSheet` usa o novo Cubit/View. `main.dart`: `BlocProvider<NewRentalCubit>`. Removido `lib/widgets/new_rental_sheet.dart`.
- [x] T7 — `test/new_rental_cubit_test.dart`: `RentalRepository.addNew`, `ScheduleRentalEndNotifications`, `NewRentalCubit` (disponibilidade, submit, sincronia com `AppState`).
- [x] T8 — `flutter analyze` limpo.
- [x] T9 — `flutter test` completo, sem alterar nenhum assert existente (79 testes — 71 anteriores + 8 novos —, todos verdes; `open_ended_rental_test.dart`'s teste de UI do formulário intacto).
- [x] T10 — Revisão manual dos critérios de aceite do `spec.md` + atualizar `specs/README.md` (linha 017 vira `Implemented`).

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
