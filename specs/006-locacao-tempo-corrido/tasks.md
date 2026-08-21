# Tasks: Locação em tempo corrido

Referência: [spec.md](spec.md) + [plan.md](plan.md).

- [x] T1 — `Rental.durationMin` nullable, `price` mutável, `isOpenEnded` getter
- [x] T2 — `AppState`: `RentalDraft.openEnded`, `ratePerMinute`, `computeFinalPrice`
- [x] T3 — `submitNew()` cria locação tempo corrido (`durationMin: null`, `price: 0`)
- [x] T4 — `confirmEnd()` calcula preço final via `computeFinalPrice` antes de `finish()`
- [x] T5 — `NewRentalSheet`: toggle tempo fixo/corrido, oculta campos irrelevantes, mostra taxa/min
- [x] T6 — `ActiveTab`/`_ActiveCard`: variante crescente (`_fmtElapsed`) sem `StripedProgress`/overtime
- [x] T7 — `EndRentalDialog`: resumo usa `computeFinalPrice` (valor certo antes de confirmar)
- [x] T8 — teste unitário de `computeFinalPrice` (22min = R$11,00, caso fracionário 22min37s = R$11,31, tempo fixo inalterado) — `test/open_ended_rental_test.dart`
- [x] T9 — teste de widget: criar/finalizar tempo corrido (valor calculado bate), criar/cancelar (sem cobrança), toggle da sheet
- [x] T10 — `flutter analyze` limpo, `flutter test` (13 testes) passando, evidência visual em `evidence/nova-locacao-toggle.png`

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`. Se algo quebrar no meio, parar ali (regra de não-quebra), não emendar.
