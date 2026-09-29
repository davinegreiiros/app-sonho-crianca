# Plan: Migração — Painel do dia (Home)

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Igual ao `ReportCubit` (014) em forma — cross-repository, só leitura derivada, sem Use Case dedicado — mas com um ticker de 1s (que o Report não precisava) pra manter "há N min" atualizado, e sem filtro de período (sempre "hoje" + ativas).

1. **`HomeState`** — `recentActivity: List<Rental>`, `activeCount`, `availableCount`, `doneTodayCount`, `homeTotalToday`, mais o catálogo completo (`toys`) pra `toyById` resolver qualquer rental da lista (mesmo padrão de `ReportState.toyById`).
2. **`HomeCubit`** — `_compute` estático replica exatamente `AppState.recentActivity`/`doneToday`/`homeTotalToday`/disponibilidade (soma de `ComputeToyAvailability` por toy). Escuta `ToyRepository`+`RentalRepository`, mais um `Timer.periodic(1s)` pra reemitir (mantém `formatRelativeTime` fresco nos itens de atividade recente, mesma garantia que o ticker global de `AppState` já dava a essa tela).
3. **`HomeView`** — cópia de `home_tab.dart`, trocando `AppState` por `HomeCubit`, `state.fmtMoney`/`whenLabel` por `formatMoney`/`formatRelativeTime`.
4. **`AppState`**: remove `recentActivity`, `doneAll`, `doneToday`, `homeTotalToday`, `_startOfDay` (confirmado sem outro consumidor via grep). `activeRentals`/`toyAvailable`/`toyById`/`fmtMoney`/`whenLabel` ficam como estão.
5. **`home_shell.dart`**/`main.dart`: `HomeView`/`BlocProvider<HomeCubit>`.
6. Remove `lib/screens/tabs/home_tab.dart`.

## Arquivos afetados

- `lib/ui/features/home/view_models/home_state.dart` — novo.
- `lib/ui/features/home/view_models/home_cubit.dart` — novo.
- `lib/ui/features/home/views/home_view.dart` — novo (movido de `home_tab.dart`).
- `lib/screens/tabs/home_tab.dart` — removido.
- `lib/state/app_state.dart` — remove os membros de home; import de `Rental`/`RentalStatus` etc. permanece (ainda usado por `activeRentals`/outros).
- `lib/screens/home_shell.dart`, `lib/main.dart` — atualizados.
- `test/home_cubit_test.dart` — novo.

## Modelo de dados / estado

`HomeState` novo (Equatable). Nenhum domain model muda.

## Riscos / dependências

- Risco baixo — mesmo perfil que a 014 (Relatório): sem consumidor fora de escopo, remoção limpa em vez de proxy.
- Depende de 012 (`ToyCatalogCubit`/`ComputeToyAvailability`), 013 (`RentalRepository`).
- Última fatia do roadmap de locação — depois dela, revisar `full_app_journey_test.dart` pra confirmar que cobre a jornada completa também pelo Painel (já cobre boot/nav/stats indiretamente).

## Alternativas consideradas

- **Reusar `ReportCubit` pro painel (mesma tela lê os dois).** Descartado — são dois recortes de dado diferentes (Report é filtrado por período, Home é sempre "hoje" + ativas, e tem contagem de disponibilidade que Report não usa); forçar um Cubit só pros dois cresceria acoplamento sem necessidade.
