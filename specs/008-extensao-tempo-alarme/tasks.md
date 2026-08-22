# Tasks: Adicionar tempo e alarme visual de tempo esgotado

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `lib/models/rental.dart`: `durationMin` deixa de ser `final`.
- [x] T2 — `lib/test_keys.dart`: `extendRentalButton(rentalId, minutes)`.
- [x] T3 — `lib/state/app_state.dart`: `extendActive(rentalId, addMinutes)` — soma duração/preço, cancela+reagenda notificação, no-op em open-ended.
- [x] T4 — `lib/screens/tabs/active_tab.dart`: botão "+ tempo" com chips 5/10/15 min no `_ActiveCard` (só `!openEnded`), chamando `state.extendActive`.
- [x] T5 — `lib/screens/tabs/active_tab.dart`: ícone de alarme pulsando (`Pulse` + ícone) visível quando `overtime`, ao lado do relógio.
- [x] T6 — teste unitário `extendActive`: duração/preço corretos (cenário 1 do spec), no-op em `isOpenEnded` (`test/extend_rental_test.dart`).
- [x] T7 — teste widget: botão "+ tempo" ausente em card open-ended, presente em card fixo; alarme visual aparece só em overtime (`test/extend_time_widget_test.dart`).
- [x] T8 — `flutter analyze` limpo + `flutter test` completo passando (38 testes) + revisão manual dos critérios de aceite do `spec.md`.

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
