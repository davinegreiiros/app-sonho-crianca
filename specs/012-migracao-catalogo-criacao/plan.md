# Plan: Migração — Catálogo (criação de brinquedo)

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Mesmo padrão strangler fig da 011, mais simples num eixo (sem persistência a migrar) e um pouco mais espalhado no outro (mais consumidores de `AppState.toys` fora de escopo).

1. **`ToyRepository extends ChangeNotifier`** — `_toys` semeado de `kInitialToys` no construtor (sem `load()` assíncrono, ao contrário da 011: não há `SharedPreferences` aqui). `addNew(...)` monta o `Toy` (gera o id — mesma regra `custom_<microssegundos>` que `AppState.addToy` já usava) e retorna; `updatePrice`/`updateBlockMinutes`/`remove` espelham os antigos `AppState.updateToyPrice`/`updateToyBlock`/`removeToy` (o `remove` do Repository é incondicional — a guarda "tem locação, não remove" continua em `AppState.removeToy`, que é quem tem acesso a `rentals`).
2. **`ToyCatalogCubit`** — recebe o `Repository`, estado = `ToyCatalogState(toys: repository.toys)`, reemite quando o `Repository` notifica, expõe `addToy(...)` repassando pro `Repository.addNew(...)`. Guarda a lista de brinquedos no estado mesmo sem `AddToySheetView` precisar dela — é o mesmo Cubit que a fatia 014 vai reaproveitar pra `catalog_tab.dart`.
3. **`AddToySheetView`** — cópia de `AddToySheet` trocando `context.watch<AppState>()` por `context.read<ToyCatalogCubit>()` (a tela nunca observava o valor, só chamava `addToy` no clique — `read` é o certo, não muda nada observável) e `state.addToy(...)` por `cubit.addToy(...)`.
4. **`AppState`**: `toyRepository` vira parâmetro nomeado opcional (mesmo padrão de `businessSettingsRepository`), escuta o repository (`addListener(notifyListeners)`) no construtor. `toys` vira getter (`_toyRepository.toys`); `_seed()` para de atribuir `toys = kInitialToys...` (o Repository já nasce semeado). `updateToyPrice`/`updateToyBlock`/`addToy` viram repasses finos pro Repository (sem `notifyListeners()` próprio — o relay do passo anterior já cobre). `toyById`/`toyAvailable`/`toyHasRentals`/`removeToy` continuam com a mesma implementação — `toyAvailable`/`toyHasRentals` dependem de `rentals`, que segue em `AppState` até a 014; `removeToy` guarda com `toyHasRentals` e só então chama `_toyRepository.remove(id)`.
5. **`main.dart`**: `ChangeNotifierProvider<ToyRepository>` novo, injetado em `AppState` e num `BlocProvider<ToyCatalogCubit>` novo — mesmo padrão de `BusinessSettingsRepository`/`BusinessSettingsCubit` da 011.
6. **`modal_launchers.dart`**: `showAddToySheet` empurra `AddToySheetView`.
7. **`test/catalog_tickets_test.dart`**: o teste que monta `AddToySheet` isolado troca `ChangeNotifierProvider<AppState>` por `BlocProvider<ToyCatalogCubit>` — mudança de bootstrap, não de asserts (o widget não depende mais de `AppState`, então nem precisa mais dele na árvore).
8. Remove `lib/widgets/add_toy_sheet.dart`.

## Arquivos afetados

- `lib/data/repositories/toy_repository.dart` — novo.
- `lib/ui/features/catalog/view_models/toy_catalog_state.dart` — novo (`Equatable`).
- `lib/ui/features/catalog/view_models/toy_catalog_cubit.dart` — novo.
- `lib/ui/features/catalog/views/add_toy_sheet_view.dart` — novo (movido de `add_toy_sheet.dart`).
- `lib/widgets/add_toy_sheet.dart` — removido.
- `lib/state/app_state.dart` — `toys`/`updateToyPrice`/`updateToyBlock`/`addToy` viram proxy; construtor ganha `toyRepository` opcional; `_seed()` não seta mais `toys`.
- `lib/main.dart` — provê `ToyRepository` compartilhado + `BlocProvider<ToyCatalogCubit>`.
- `lib/widgets/modal_launchers.dart` — `showAddToySheet` usa `AddToySheetView`.
- `test/catalog_tickets_test.dart` — bootstrap do teste de `AddToySheet` isolado troca pra `BlocProvider<ToyCatalogCubit>`.
- `test/toy_catalog_cubit_test.dart` — novo: cobre `ToyRepository`/`ToyCatalogCubit` sem `WidgetTester`.

## Modelo de dados / estado

`Toy` (domain model) não muda nenhum campo. Novo: `ToyCatalogState` (`Equatable`, campo `toys: List<Toy>`).

## Riscos / dependências

- Mesmo risco da 011: `AppState` e a nova tela lendo instâncias diferentes de `ToyRepository` — mitigado pela instância única em `main.dart` e pelo cenário de usuário #3.
- Maior superfície de consumidores fora de escopo que a 011 (6 arquivos leem `toys`/`toyById` via `AppState`, contra 2 na 011) — mitigado por eles não precisarem de nenhuma mudança de código (só a implementação por trás do getter/métodos muda).
- Depende das fatias 010 e 011 já implementadas (mesmos padrões de DI/proxy).

## Alternativas consideradas

- **Migrar `catalog_tab.dart` também nesta fatia.** Descartado — é o "Aprendizado da fatia 012" registrado na spec 010: exigiria `ToyCatalogCubit` depender de `rentals`/`AppState` (inverte a direção da migração) antes de `RentalRepository` existir.
- **`ToyRepository.remove` já verificar `toyHasRentals` internamente.** Descartado: exigiria o Repository de Toy conhecer `Rental`, virando cross-repository — a guarda fica em `AppState` (que já tem `rentals`) até a 014, quando um use case dedicado pode assumir essa regra de forma mais limpa.
