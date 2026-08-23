# Tasks: Migração — Catálogo (criação de brinquedo)

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `ToyRepository` (`lib/data/repositories/`): semeia de `kInitialToys`, `addNew()`/`updatePrice()`/`updateBlockMinutes()`/`remove()`, `ChangeNotifier`.
- [x] T2 — `ToyCatalogState` (Equatable) + `ToyCatalogCubit` (`lib/ui/features/catalog/view_models/`).
- [x] T3 — `AddToySheetView` (`lib/ui/features/catalog/views/`) — mover UI de `add_toy_sheet.dart`, trocar `AppState` por `ToyCatalogCubit`.
- [x] T4 — `AppState`: `toyRepository` opcional no construtor, `toys`/`updateToyPrice`/`updateToyBlock`/`addToy` viram proxy, `_seed()` não seta mais `toys`.
- [x] T5 — `main.dart`: instância única de `ToyRepository`, provida pro `AppState` e pro `BlocProvider<ToyCatalogCubit>`.
- [x] T6 — `modal_launchers.dart`: `showAddToySheet` usa `AddToySheetView`. Removido `lib/widgets/add_toy_sheet.dart`.
- [x] T7 — `test/catalog_tickets_test.dart`: bootstrap do teste isolado de `AddToySheet` trocado pra `BlocProvider<ToyCatalogCubit>` + `AddToySheetView`.
- [x] T8 — `test/toy_catalog_cubit_test.dart`: `addNew` gera id único e emite estado novo; sincronia com `AppState` via mesma instância de `Repository`.
- [x] T9 — `flutter analyze` limpo.
- [x] T10 — `flutter test` completo, sem alterar asserts existentes (50 testes — 44 anteriores + 6 novos —, todos verdes).
- [x] T11 — Revisão manual dos critérios de aceite do `spec.md` + atualizar `specs/README.md` (linha 012 vira `Implemented`).

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
