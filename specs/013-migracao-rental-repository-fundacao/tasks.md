# Tasks: Migração — RentalRepository (fundação)

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `RentalRepository` (`lib/data/repositories/`): seed idêntico ao de `AppState._seed()` (11 registros, helpers `minAgo`/`dAgo`/`todayAt`), `add()`/`removeById()`, `ChangeNotifier`. Lista exposta mutável (não `List.unmodifiable`) — ver nota no `plan.md`.
- [x] T2 — `AppState`: `rentalRepository` opcional no construtor, `rentals` vira getter proxy, `_seed()` não monta mais a lista, `submitNew`/`cancelActive` chamam o Repository.
- [x] T3 — `main.dart`: instância única de `RentalRepository`, provida pro `AppState`.
- [x] T4 — `test/rental_repository_test.dart`: seed tem os IDs esperados; `add`/`removeById` mudam a lista e notificam.
- [x] T5 — `flutter analyze` limpo.
- [x] T6 — `flutter test` completo, sem alterar nenhum assert existente (54 testes — 50 anteriores + 4 novos —, todos verdes; corrigido no processo: `open_ended_rental_test.dart` mutava `state.rentals` por índice, exigiu lista mutável no Repository em vez de `List.unmodifiable`).
- [x] T7 — Revisão manual dos critérios de aceite do `spec.md` + atualizar `specs/README.md` (linha 013 vira `Implemented`).

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
