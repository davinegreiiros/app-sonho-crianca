# Plan: Migração — Relatório

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Primeira fatia sem nenhum consumidor fora de escopo (`reportPeriod`/`reportFiltered`/etc. só existiam pro `report_tab.dart`) — por isso, ao contrário de 011/012/013, `AppState` não vira proxy: o código é removido de vez. Também é a primeira fatia com um Cubit cross-repository de verdade (`RentalRepository` + `ToyRepository`), mas sem precisar de Use Case — é leitura derivada, não regra de negócio reusada em outro lugar.

1. **`lib/ui/core/formatters.dart`** — `formatMoney(double)` e `formatRelativeTime(DateTime)`, funções puras copiadas de `AppState.fmtMoney`/`whenLabel` sem alterar a lógica. `AppState.fmtMoney`/`whenLabel` passam a chamar essas funções (assinatura pública inalterada — `active_tab.dart`, `home_tab.dart`, etc. continuam chamando `state.fmtMoney(...)` sem saber da mudança).
2. **`ReportPeriod` + `ReportState`** (`lib/ui/features/report/view_models/report_state.dart`) — `ReportPeriod` sai de `app_state.dart` pra cá (só a fatia Relatório usa). `ReportState` troca `MapEntry<Toy, ({int count, double total})>` por `({Toy toy, int count, double total})` (record puro, sem `MapEntry`) — mesma informação, API mais limpa.
3. **`ReportCubit`** (`lib/ui/features/report/view_models/report_cubit.dart`) — recebe `RentalRepository`/`ToyRepository` via construtor (parâmetros nomeados normais, não `this.x`, porque o estado inicial precisa ser calculado *antes* do `super(...)` — não dá pra ler um campo `this.` na initializer list). Escuta os dois repositories (`addListener`) e recalcula (`_compute`) a cada notificação ou `setPeriod(...)`. `_compute` é `static`, replica exatamente as fórmulas que estavam em `AppState` (`_reportCutoff`, `reportFiltered`, `reportTotal`, `paymentBreakdown`, `toyBreakdown` com sort desc. por total, `historyList` com sort desc. por `endedAt`).
4. **`ReportView`** (`lib/ui/features/report/views/report_view.dart`) — cópia de `report_tab.dart`, trocando `context.watch<AppState>()` por `context.watch<ReportCubit>()` (lê `.state`), `state.setReportPeriod` por `cubit.setPeriod`, `state.fmtMoney`/`whenLabel` por `formatMoney`/`formatRelativeTime`, e o acesso a `toyBreakdown` de `entry.key`/`entry.value.count`/`entry.value.total` pra `entry.toy`/`entry.count`/`entry.total`.
5. **`AppState`**: remove (não proxya) `reportPeriod`, `setReportPeriod`, `reportFiltered`, `reportTotal`, `paymentBreakdown`, `toyBreakdown`, `historyList`, `_reportCutoff`, `_reportWindowDays`, `ReportPeriod`. `fmtMoney`/`whenLabel` passam a delegar pro `lib/ui/core/formatters.dart`.
6. **`main.dart`**: `BlocProvider<ReportCubit>` novo, criado com `context.read<RentalRepository>()`/`context.read<ToyRepository>()` (já providos desde as fatias 012/013).
7. **`home_shell.dart`**: `AppTab.report => const ReportTab()` vira `const ReportView()`.
8. Remove `lib/screens/tabs/report_tab.dart`.

## Arquivos afetados

- `lib/ui/core/formatters.dart` — novo.
- `lib/ui/features/report/view_models/report_state.dart` — novo (`ReportPeriod` + `ReportState`, `Equatable`).
- `lib/ui/features/report/view_models/report_cubit.dart` — novo.
- `lib/ui/features/report/views/report_view.dart` — novo (movido de `report_tab.dart`).
- `lib/screens/tabs/report_tab.dart` — removido.
- `lib/state/app_state.dart` — remove os membros de relatório; `fmtMoney`/`whenLabel` delegam pro formatter compartilhado.
- `lib/screens/home_shell.dart` — usa `ReportView`.
- `lib/main.dart` — `BlocProvider<ReportCubit>` novo.
- `test/report_cubit_test.dart` — novo: filtro de período, totais, breakdowns, sincronia via Repository compartilhado.
- `test/report_view_test.dart` — novo: primeira cobertura de widget test pra essa tela.

## Modelo de dados / estado

`ReportState` novo (Equatable): `period`, `total`, `filteredCount`, `paymentBreakdown: Map<PaymentMethod, double>`, `toyBreakdown: List<({Toy toy, int count, double total})>`, `historyList: List<Rental>`. `ReportPeriod` (enum) migra de `app_state.dart` pra cá, mesmos 3 valores (`today`, `week`, `all`).

## Riscos / dependências

- Depende de `RentalRepository` (013) e `ToyRepository` (012) já implementados.
- Risco baixo: nenhum outro consumidor de relatório, e não existia teste prévio pra quebrar — mas por isso mesmo os testes novos (unit + widget) são o único jeito de garantir paridade, não tem rede de segurança pré-existente.

## Alternativas consideradas

- **`AppState` continuar proxyando `reportPeriod`/etc. em vez de remover.** Descartado: diferente de `Toy`/`BusinessSettings`/`Rental`, nada mais lê esses campos depois que `report_tab.dart` migra — manter proxy seria código morto.
- **Use Case dedicado pro cálculo de breakdown.** Descartado por ora (decisão já registrada na spec 010: use case só se lógica for complexa ou reusada por mais de um Cubit) — é leitura derivada só usada pelo `ReportCubit`.
- **Manter `MapEntry<Toy, record>` em vez de um record puro.** Descartado — o record `({Toy toy, int count, double total})` é mais legível no `ReportView` (`entry.toy` em vez de `entry.key`) e não perde nada.
