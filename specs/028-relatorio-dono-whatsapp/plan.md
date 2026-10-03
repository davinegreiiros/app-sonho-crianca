# Plan: Relatório do dono + envio pelo WhatsApp

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Tudo em cima do `ReportCubit`/`ReportView` já migrados (spec 014). Nenhum Repository novo, nenhum dado novo persistido: é leitura derivada de `RentalRepository` + `ToyRepository` + `TurnoRepository`, mais um ponto de saída (compartilhar texto).

### Regra do caixa do turno num lugar só

Hoje a conta "esperado por forma de pagamento num turno" está escrita duas vezes: `PostoSessionCubit.beginClosing` (fechamento, 3c) e `AdminPanelCubit._compute` (painel, 3d). Ambas usam a mesma regra — locações `done` do `toyId` do turno, recebidas pelo monitor do turno (`finishedByMonitorName == turno.monitorName`), com `endedAt` a partir de `openedAt` (o painel também limita em `closedAt`, ou agora se aberto) — mas duplicada. O relatório seria a terceira cópia.

Cancelada é `done` sem forma de pagamento desde a 026: entra na lista do turno (o fechamento conta ela em "N locações", como já fazia) mas nunca soma em nenhuma forma de pagamento. O painel continua filtrando `isCompleted` pro próprio bruto/contagem.

Vira um Use Case, `ComputeTurnoCash` (`lib/domain/use_cases/`), reusado pelos três Cubits — exatamente o caso que a constitution reserva pra Use Case (lógica reusada por mais de um Cubit). `PostoSessionCubit` e `AdminPanelCubit` passam a delegar pra ele sem mudar comportamento (testes existentes da 023 continuam valendo). Um teste novo garante que relatório e fechamento dão o mesmo número pro mesmo turno.

Nota: na `main` (antes da 026) a implementação filtrava só por `toyId` + janela; a `develop` passou a filtrar também pelo monitor, como a spec 023 descreve. Esta spec segue a `develop` e não muda a regra.

### Períodos

`ReportPeriod` ganha `month` e `week` muda de significado (de "últimos 14 dias" pra "semana de calendário"):

- `today`: hoje 00:00.
- `week`: segunda-feira 00:00 da semana atual (`DateTime(y, m, d - (weekday - 1))`).
- `month`: dia 1 do mês atual 00:00.
- `all`: epoch.

Hora local do aparelho. `ReportCubit` recebe um relógio injetável (`DateTime Function() clock`, padrão `DateTime.now`) — os cortes dependem do dia da semana, e teste com data real ficaria instável.

### Compartilhar

- Interface `TextSharer` em `lib/domain/` (mesmo molde de `RentalNotifier`): `Future<void> share(String text, {Rect? origin})`.
- Implementação `SharePlusTextSharer` em `lib/data/services/`, usando `share_plus` (`SharePlus.instance.share(ShareParams(text:, sharePositionOrigin:))`).
- `origin`: no iPad a folha de compartilhamento abre como popover e precisa de um retângulo de origem, senão não abre. A View passa o retângulo do botão.
- `ReportCubit` recebe `TextSharer?` (padrão `SharePlusTextSharer()`), expõe `summaryText()` e `shareSummary({Rect? origin})`. Teste injeta fake que grava o texto.
- `SonhoDeCriancaApp` ganha `textSharer` opcional (mesmo padrão dos Repositories opcionais) pra teste de widget.

**Permissões**: `share_plus` 12 não declara `<uses-permission>` no Android (só um `FileProvider` e um `receiver`, ambos `exported=false`, usados pra compartilhar arquivo — aqui só texto). iOS não pede nada. Nenhuma permissão nova no app.

### Texto do resumo

Função pura `buildReportSummary(...)` em `lib/ui/features/report/view_models/report_summary.dart` — formatação de apresentação, testável sem widget. Recebe o `ReportState` e o `now`; não recebe `Rental` cru, só os agregados, então por construção não tem como vazar `childName`/`guardianName`/`guardianPhone` (e há teste dedicado mesmo assim).

Cabeçalho por período:
- Hoje: `Sonho de Criança — Hoje, 03/10/2026`
- Semana: `Sonho de Criança — Semana de 28/09 a 03/10/2026`
- Mês: `Sonho de Criança — Outubro/2026`
- Tudo: `Sonho de Criança — Todo o período`

Valores com `formatMoney` (o formatador do app; sem separador de milhar — o exemplo da spec é ilustrativo). Diferença de caixa com sinal explícito (`+R$ 5,00` / `-R$ 20,00`).

## Arquivos afetados

- `pubspec.yaml` — `share_plus: ^12.0.2`.
- `lib/domain/use_cases/compute_turno_cash.dart` — novo: esperado por forma de pagamento + diferença de caixa de um turno.
- `lib/domain/text_sharer.dart` — novo: interface.
- `lib/data/services/share_plus_text_sharer.dart` — novo: implementação.
- `lib/ui/features/report/view_models/report_state.dart` — `ReportPeriod.month`; estado ganha `monitorBreakdown`, `cashDiffTurnos`, `closedTurnosCount`, `cashDiffTotal`, `now`.
- `lib/ui/features/report/view_models/report_cubit.dart` — cortes novos, agrupamento por monitor, caixa do período, `TurnoRepository`/`TextSharer`/relógio injetados, `summaryText`/`shareSummary`.
- `lib/ui/features/report/view_models/report_summary.dart` — novo: texto do resumo.
- `lib/ui/features/report/views/report_view.dart` — 4 períodos, seções "POR MONITOR" e "CAIXA", botão "Enviar resumo".
- `lib/ui/features/posto/view_models/posto_session_cubit.dart`, `lib/ui/features/admin_panel/view_models/admin_panel_cubit.dart` — delegam pro `ComputeTurnoCash` (sem mudança de comportamento).
- `lib/main.dart` — `ReportCubit` recebe `TurnoRepository` e `textSharer`; `SonhoDeCriancaApp.textSharer` opcional.
- `lib/test_keys.dart` — `reportShareButton`, `reportPeriodKey(...)`.
- `test/report_cubit_test.dart`, `test/report_summary_test.dart` (novo), `test/compute_turno_cash_test.dart` (novo), `test/report_view_test.dart`, `test/full_app_journey_test.dart` ("14 dias" → "Semana").

## Modelo de dados / estado

Nenhum domain model muda. Só o `ReportState` (envelope do Cubit) ganha campos.

## Riscos / dependências

- **Mudança de significado de `ReportPeriod.week`**: só o `ReportCubit` e testes usam o enum (verificado por busca). Teste da jornada completa procura o texto "14 dias" — ajustado.
- **Refactor do caixa nos Cubits da 023**: coberto pelos testes existentes de `posto_monitor_painel_test.dart`; qualquer quebra para a spec (regra de não-quebra).
- **Dado por aparelho**: `Rental`/`Turno` locais (fora de escopo da spec).

## Alternativas consideradas

- **`url_launcher` com `wa.me/?text=`**: abre direto o WhatsApp, mas só ele, e falha se o app não estiver instalado. A folha do sistema mostra WhatsApp e qualquer outro.
- **Texto montado na View**: misturaria regra com widget e não daria pra testar sem `WidgetTester`.
