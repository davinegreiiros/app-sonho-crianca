# Tasks: Migração — Catálogo (grade e tickets de disponibilidade)

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `ComputeToyAvailability` em `lib/domain/use_cases/`.
- [x] T2 — `ToyCatalogState` ganha `availability`/`availabilityOf`.
- [x] T3 — `ToyCatalogCubit`: injeta `RentalRepository`, `updatePrice`/`updateBlockMinutes`/`removeToy`.
- [x] T4 — `CatalogView` em `lib/ui/features/catalog/views/` — mover UI de `catalog_tab.dart`, trocar `AppState` por `ToyCatalogCubit`, manter `_TicketStub` com nome idêntico.
- [x] T5 — `home_shell.dart` usa `CatalogView`. `main.dart`: `BlocProvider<ToyCatalogCubit>` recebe `RentalRepository`. Removido `lib/screens/tabs/catalog_tab.dart`.
- [x] T6 — Atualizado `test/toy_catalog_cubit_test.dart`/`test/catalog_tickets_test.dart` pra passar `RentalRepository` também.
- [x] T7 — Cobertura de `ComputeToyAvailability`/disponibilidade/sincronia/`removeToy` no teste unit do Cubit (4 testes novos).
- [x] T8 — `flutter analyze` limpo.
- [x] T9 — `flutter test` completo, sem alterar nenhum assert existente (71 testes — 67 anteriores + 4 novos —, todos verdes; `test/catalog_tickets_test.dart` intacto).
- [x] T10 — `test/full_app_journey_test.dart` rodou junto na suíte completa e passou, já exercitando o catálogo migrado.
- [x] T11 — Revisão manual dos critérios de aceite do `spec.md` + atualizar `specs/README.md` (linha 015 vira `Implemented`).

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
