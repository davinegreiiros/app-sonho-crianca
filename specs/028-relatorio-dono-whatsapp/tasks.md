# Tasks: Relatório do dono + envio pelo WhatsApp

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `ComputeTurnoCash` (`lib/domain/use_cases/`) + `PostoSessionCubit`/`AdminPanelCubit` delegando pra ele; suíte da 023 verde.
- [x] T2 — `TextSharer` (`lib/domain/`) + `SharePlusTextSharer` (`lib/data/services/`); `share_plus` no `pubspec.yaml`.
- [x] T3 — `ReportState`/`ReportPeriod.month`; `ReportCubit` com cortes de semana/mês, relógio injetável, por monitor, caixa do período, `TurnoRepository`/`TextSharer`.
- [x] T4 — `buildReportSummary` + `ReportCubit.summaryText`/`shareSummary`.
- [x] T5 — `ReportView`: 4 períodos, "POR MONITOR", "CAIXA", botão "Enviar resumo" (origem pro iPad); chaves em `test_keys.dart`.
- [x] T6 — wiring em `main.dart` (`TurnoRepository` + `textSharer` opcional).
- [x] T7 — testes em `test/report_owner_test.dart` (cenários 1–8) e `test/report_view_test.dart` (seções novas + botão chama o sharer com a posição do botão).
- [x] T8 — `full_app_journey_test.dart`: "14 dias" → "Semana"/"Mês".
- [x] T9 — `flutter analyze` limpo + `flutter test` 193/193 (na `develop`, com 026/027) + `specs/README.md`.
  - Verificação visual no aparelho real **pendente**: o build Android nesta máquina segue bloqueado pelo Smart App Control (mesmo bloqueio do T20 da spec 024). Conferir no tablet: layout da aba Faturamento com 4 períodos e a folha de compartilhamento abrindo o WhatsApp.

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
