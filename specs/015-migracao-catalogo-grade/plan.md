# Plan: Migração — Catálogo (grade e tickets de disponibilidade)

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Diferente de todas as fatias anteriores, esta não toca em `AppState` — `toys`/`rentals` já são getters proxy pros Repositories compartilhados desde as fatias 012/013, e `home_tab.dart`/`new_rental_sheet.dart` continuam usando a leitura de `AppState` sem qualquer mudança. O trabalho é só: dar ao `ToyCatalogCubit` (já existe) acesso a `RentalRepository`, e migrar a View.

1. **`ComputeToyAvailability`** (`lib/domain/use_cases/compute_toy_availability.dart`) — classe callable (`class ComputeToyAvailability { const ComputeToyAvailability(); int call(Toy toy, List<Rental> rentals) => ...; }`), mesma fórmula de `AppState.toyAvailable`. Primeiro use case do projeto — justificado pela decisão da spec 010 ("só quando lógica for complexa ou reusada por mais de um Cubit"): é cross-repository e a fatia 016 (locação) provavelmente reusa a mesma fórmula.
2. **`ToyCatalogState`** ganha `availability: Map<String, int>` computado no `_compute` do Cubit, mais `availabilityOf(Toy)` de conveniência.
3. **`ToyCatalogCubit`** — construtor muda de `ToyCatalogCubit(this._repository)` pra `ToyCatalogCubit(ToyRepository toyRepository, RentalRepository rentalRepository, {ComputeToyAvailability computeToyAvailability = const ComputeToyAvailability()})`, com `_compute` estático replicando a mesma lógica de `_compute` do `ReportCubit` (soma disponibilidade por toy). Escuta os dois repositories (`addListener`). Ganha `updatePrice`, `updateBlockMinutes`, `removeToy` (guarda de "tem locação" igual `AppState.toyHasRentals`) — todos delegando pro `ToyRepository` já existente (`updatePrice`/`updateBlockMinutes`/`remove` já existem lá desde a 012).
4. **`CatalogView`** — cópia de `catalog_tab.dart`, trocando `context.watch<AppState>()` por `context.watch<ToyCatalogCubit>()`, `state.toyAvailable(toy)` por `cubit.state.availabilityOf(toy)`, `state.updateToyPrice/updateToyBlock` por `cubit.updatePrice/updateBlockMinutes`, `state.removeToy` por `cubit.removeToy`. Mantém a classe privada `_TicketStub` com o mesmo nome (testes a acham por `runtimeType`).
5. **`home_shell.dart`**: `AppTab.catalog => const CatalogTab()` vira `const CatalogView()`.
6. **`main.dart`**: `BlocProvider<ToyCatalogCubit>` passa a receber `context.read<RentalRepository>()` também.
7. Remove `lib/screens/tabs/catalog_tab.dart`.

## Arquivos afetados

- `lib/domain/use_cases/compute_toy_availability.dart` — novo (primeiro arquivo em `domain/use_cases/`).
- `lib/ui/features/catalog/view_models/toy_catalog_state.dart` — `availability` + `availabilityOf`.
- `lib/ui/features/catalog/view_models/toy_catalog_cubit.dart` — injeta `RentalRepository`, ganha `updatePrice`/`updateBlockMinutes`/`removeToy`.
- `lib/ui/features/catalog/views/catalog_view.dart` — novo (movido de `catalog_tab.dart`).
- `lib/screens/tabs/catalog_tab.dart` — removido.
- `lib/screens/home_shell.dart` — usa `CatalogView`.
- `lib/main.dart` — `BlocProvider<ToyCatalogCubit>` recebe `RentalRepository`.
- `test/toy_catalog_cubit_test.dart` — cobre `ComputeToyAvailability`/disponibilidade/sincronia.

## Modelo de dados / estado

`ToyCatalogState` ganha `availability: Map<String, int>`. Nenhum domain model muda.

## Riscos / dependências

- Depende de 012 (`ToyCatalogCubit`/`ToyRepository`) e 013 (`RentalRepository`) já implementadas.
- Risco principal: quebrar `test/catalog_tickets_test.dart` (única cobertura real dos tickets de disponibilidade hoje) — mitigado mantendo `_TicketStub` com nome idêntico e a mesma estrutura de dados que o teste espera.
- `AddToySheetView`/testes da 012 que constroem `ToyCatalogCubit` sozinho (`test/toy_catalog_cubit_test.dart`, `test/catalog_tickets_test.dart`) precisam passar a fornecer também um `RentalRepository` — mudança de assinatura de construtor, não de comportamento.

## Alternativas consideradas

- **Repository de Toy conhecer Rental diretamente (sem use case).** Descartado — inverteria a regra já estabelecida na 012/013 de que cada Repository só conhece seu próprio domínio; a lógica cross-repository é papel do Use Case/Cubit, não do Repository.
- **Criar um Cubit novo (`CatalogGridCubit`) em vez de estender o `ToyCatalogCubit` existente.** Descartado — o roadmap da 010 já previu explicitamente reaproveitar o mesmo Cubit (ele guarda a lista de brinquedos desde a 012 exatamente pra isso), e `AddToySheetView` não é afetado por ganhar campos que não usa.
