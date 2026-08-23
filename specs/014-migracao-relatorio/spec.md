# Spec: Migração — Relatório

Status: Implemented
Criado: 2026-08-23

Fatia 014 do roadmap em [specs/010-migracao-arquitetura-camadas](../010-migracao-arquitetura-camadas/spec.md) — primeira fatia a se apoiar no `RentalRepository` (013). Só leitura: filtro de período, totais, breakdowns, histórico. Sem escrita, sem timer, sem notificação.

## Problema

`report_tab.dart` lê tudo via `AppState`: `reportPeriod`/`setReportPeriod`, `reportFiltered`, `reportTotal`, `paymentBreakdown`, `toyBreakdown`, `historyList`, mais `toyById`/`fmtMoney`/`whenLabel` pra formatação. Nenhum desses é usado por mais nenhuma tela — ao contrário de `Toy`/`BusinessSettings`/`Rental` nas fatias anteriores, não existe consumidor fora de escopo aqui, então esta fatia pode remover esse código do `AppState` de vez, não só proxyar.

## Objetivo

`report_tab.dart` vira `ReportCubit` + `ReportView` (`lib/ui/features/report/`), lendo direto de `RentalRepository` + `ToyRepository` (já existem, das fatias 012/013) — sem Repository novo, sem Use Case dedicado (a lógica de filtro/breakdown é só leitura derivada, cabe direto no Cubit). `AppState` perde `reportPeriod`, `setReportPeriod`, `reportFiltered`, `reportTotal`, `paymentBreakdown`, `toyBreakdown`, `historyList` e o enum `ReportPeriod` — não viram proxy, são removidos de vez.

## Fora de escopo

- Qualquer mudança de comportamento visível, layout ou cópia de texto.
- `home_tab.dart`, `active_tab.dart` e as outras telas — continuam em `AppState` sem nenhuma mudança (`doneToday`, `homeTotalToday`, `recentActivity` ficam onde estão, são usados por `home_tab.dart`).
- Persistência de relatório — não existe hoje, não muda.

## Cenários de usuário

Paridade total:

1. Dado o app com o seed padrão, quando o operador abre a aba "Faturamento", então vê o total do período, breakdown por forma de pagamento, breakdown por brinquedo e o histórico — idênticos a antes.
2. Dado a aba "Faturamento" aberta, quando o operador troca o período (Hoje / 14 dias / Tudo), então todos os números e listas atualizam de acordo — mesmo comportamento de hoje.
3. Dado uma locação nova criada ou finalizada em outra aba (mundo `AppState`/`RentalRepository`), quando o operador volta pra "Faturamento", então os números refletem a mudança — prova de que o `ReportCubit` lê a mesma fonte de verdade, não uma cópia.

## Critérios de aceite

- [x] `formatMoney`/`formatRelativeTime` extraídos pra `lib/ui/core/formatters.dart` (funções puras, sem Flutter/BuildContext) — `AppState.fmtMoney`/`whenLabel` passam a delegar pra elas (comportamento idêntico, remove duplicação futura); `ReportView` usa as funções direto.
- [x] `ReportPeriod` (enum) e `ReportState` (`equatable`) em `lib/ui/features/report/view_models/` — campos: período atual, total, contagem de locações no período, breakdown por forma de pagamento, breakdown por brinquedo (`({Toy toy, int count, double total})`, sem `MapEntry`), lista de histórico ordenada, mais o catálogo completo (pra `toyById` resolver qualquer `Rental.toyId` do histórico, mesmo contrato que `AppState.toyById` já tinha).
- [x] `ReportCubit` (`lib/ui/features/report/view_models/`) — injeta `RentalRepository` + `ToyRepository`, recalcula o estado quando qualquer um notifica mudança ou quando `setPeriod(...)` é chamado. Mesma fórmula de filtro/corte de período (`hoje` = início do dia, `14 dias` = `DateTime.now() - 14 dias`, `tudo` = epoch) e mesma ordenação (breakdown por brinquedo desc. por total, histórico desc. por `endedAt`) que `AppState` tinha.
- [x] `ReportView` (`lib/ui/features/report/views/`) substitui `lib/screens/tabs/report_tab.dart` — mesmo layout/textos, lendo de `ReportCubit` em vez de `AppState`. `home_shell.dart` aponta pra ela.
- [x] `AppState` perde `reportPeriod`, `setReportPeriod`, `reportFiltered`, `reportTotal`, `paymentBreakdown`, `toyBreakdown`, `historyList`, `_reportCutoff`, `_reportWindowDays` e o enum `ReportPeriod` — removidos, não proxyados (nenhum outro consumidor).
- [x] `main.dart` registra `BlocProvider<ReportCubit>` (injetando os Repositories já providos).
- [x] Teste novo (unit, sem `WidgetTester`) cobrindo `ReportCubit`: total/breakdown/histórico corretos pro seed padrão em cada período; sincronia com `RentalRepository` compartilhado (uma locação nova/finalizada em outro lugar aparece no relatório).
- [x] Teste novo (widget) cobrindo `ReportView`: abre a aba, trocar de período muda o total exibido — primeira cobertura de teste que esta tela ganha (não tinha nenhuma antes).
- [x] `flutter analyze` limpo.
- [x] Toda a suíte de testes existente passa sem alterar nenhum assert (60 testes, todos verdes).

## Requisitos não-funcionais

- `ReportCubit` testável com `flutter_test` puro, sem `WidgetTester`.
- Sem duplicar a lógica de formatação de dinheiro/tempo relativo entre `AppState` e a fatia nova.

## Dúvidas em aberto

Nenhuma bloqueante.
