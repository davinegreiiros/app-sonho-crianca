# Tasks: Migração — Relatório

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `lib/ui/core/formatters.dart`: `formatMoney`/`formatRelativeTime`, copiados de `AppState.fmtMoney`/`whenLabel`.
- [x] T2 — `AppState.fmtMoney`/`whenLabel` passam a delegar pros formatters.
- [x] T3 — `ReportPeriod` + `ReportState` (Equatable) em `lib/ui/features/report/view_models/report_state.dart`.
- [x] T4 — `ReportCubit` em `lib/ui/features/report/view_models/report_cubit.dart` — `_compute` replica as fórmulas de `AppState`, escuta `RentalRepository`/`ToyRepository`, `setPeriod(...)`.
- [x] T5 — `ReportView` em `lib/ui/features/report/views/report_view.dart` — mover UI de `report_tab.dart`, trocar `AppState` por `ReportCubit` + os formatters.
- [x] T6 — `AppState`: removido `reportPeriod`/`setReportPeriod`/`reportFiltered`/`reportTotal`/`paymentBreakdown`/`toyBreakdown`/`historyList`/`_reportCutoff`/`_reportWindowDays`/`ReportPeriod`.
- [x] T7 — `main.dart`: `BlocProvider<ReportCubit>`. `home_shell.dart`: usa `ReportView`. Removido `lib/screens/tabs/report_tab.dart`.
- [x] T8 — `test/report_cubit_test.dart`: totais/breakdowns/histórico por período no seed padrão; sincronia via Repository compartilhado.
- [x] T9 — `test/report_view_test.dart`: abre a aba, troca de período, total exibido muda (achado no processo: precisou `scrollUntilVisible` pros headers mais abaixo na lista — `ListView` é lazy e o header do app reduz a viewport visível no teste).
- [x] T10 — `flutter analyze` limpo.
- [x] T11 — `flutter test` completo, sem alterar nenhum assert existente (60 testes — 54 anteriores + 6 novos —, todos verdes).
- [x] T12 — Revisão manual dos critérios de aceite do `spec.md` + atualizar `specs/README.md` (linha 014 vira `Implemented`).

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
