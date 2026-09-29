# Plan: Posto do monitor + fechamento de turno + painel administrativo

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

O app ganha uma "sessão de posto" na raiz da árvore de widgets, ao lado de `AppShellCubit`: um `PostoSessionCubit` novo que decide, em `SonhoDeCriancaApp`, qual das três coisas mostrar no lugar do `MaterialApp.home` atual — `OpenPostoView` (3a, `mode == none`, estado inicial sempre que o app abre), `MonitorPostoView` (3b, `mode == monitor`) ou o `HomeShell` de hoje inalterado (`mode == admin`). Isso é feito com um `BlocBuilder<PostoSessionCubit, PostoSessionState>` novo envolvendo o `home:` do `MaterialApp` — nenhuma rota nomeada nova, mesmo racional de `MaterialPageRoute` que `openBusinessSettingsScreen` já usa pra 3c/3d (navegação em cima da árvore existente).

`PostoSessionCubit` é o ViewModel único que cobre 3a (lista de postos livres/ocupados + abrir/retomar) e a mecânica de 3c (esperado por forma de pagamento do turno atual + confirmar fechamento) — ele já precisa ouvir `RentalRepository`/`ToyRepository`/`TurnoRepository` pra montar a lista de postos, então calcular o esperado do turno ali reaproveita a mesma inscrição, sem Cubit extra. 3b (locações ativas do posto) reaproveita `ActiveRentalsCubit` já existente, filtrando `activeRentals` por `toyId` na própria View (o Cubit continua "global" porque o painel administrativo — modo admin — continua precisando ver todas as locações de todos os toys, comportamento de hoje). "Colocar criança" em 3b reaproveita `NewRentalCubit`/`showNewRentalSheet` de sempre, só travando o `toyId` (`setToy` logo após `open()`, sem mostrar o seletor de brinquedo na sheet quando aberta a partir do posto).

Autoria (`createdByMonitorName`/`finishedByMonitorName`) não vira um novo acoplamento entre Cubits — cada ponto de escrita (botão "Colocar criança" dentro da sheet, botão de confirmar em `EndRentalDialogView`) lê `context.read<PostoSessionCubit>().state.monitorName` (`null` em modo admin) no exato `onPressed` e passa como parâmetro pro método do Cubit, que só repassa pro Repository — mesmo estilo dos outros call sites deste app (`modal_launchers.dart` já lê Repository direto num call site pontual).

3d (`AdminPanelView`) ganha seu próprio `AdminPanelCubit`, read-only, no mesmo molde do `ReportCubit` já existente (período fixo "hoje", recalcula quando `RentalRepository`/`ToyRepository`/`TurnoRepository` mudam) — não reaproveita `ReportCubit` porque a granularidade é outra (por **turno**, não por toy agregado no dia inteiro) e porque a trilha aqui precisa da autoria, que `ReportState.historyList` não carrega.

## Arquivos afetados

- `lib/domain/models/turno.dart` — **novo**: modelo `Turno` (id, toyId, monitorName, openedAt, closedAt, countedCash), mesmo estilo mutável pontual de `Rental` (só os 2 campos que o fechamento preenche depois deixam de ser `final`).
- `lib/domain/models/rental.dart` — **alterado**: 2 campos novos `String? createdByMonitorName`, `String? finishedByMonitorName` no construtor (opcionais, default `null`) e em `finish()` (recebe `finishedByMonitorName` opcional).
- `lib/data/services/app_database.dart` — **alterado**: `_version` 1 → 2; `_onCreate` ganha as 2 colunas novas em `rentals` e a tabela `turnos`; `onUpgrade` novo faz `ALTER TABLE rentals ADD COLUMN ...` (x2) + `CREATE TABLE turnos` pra quem já tem banco na v1 — sem perder dado (regra da spec).
- `lib/data/services/rental_local_service.dart` — **alterado**: `_toRow`/`_fromRow` ganham as 2 colunas novas.
- `lib/data/services/turno_local_service.dart` — **novo**: wrapper CRUD sobre a tabela `turnos`, mesmo padrão de `RentalLocalService`.
- `lib/data/repositories/rental_repository.dart` — **alterado**: `addNew({..., String? createdByMonitorName})` e `finish(id, method, {..., String? finishedByMonitorName})` passam os campos novos pro `Rental`/persistência.
- `lib/data/repositories/turno_repository.dart` — **novo**: fonte única de verdade de `Turno`s, mesmo padrão de `ToyRepository`. `openTurnoFor(toyId)` (retorna o turno aberto daquele toy, se houver — nunca mais de um), `open(toyId, monitorName)` (recusa/no-op se já existe aberto pro mesmo `toyId` — trava do cenário 7 do spec), `close(turnoId, {required double countedCash})`.
- `lib/ui/features/posto/view_models/posto_session_state.dart` + `posto_session_cubit.dart` — **novo**: sessão (`mode`: none/monitor/admin), lista de postos pra 3a (toy + turno aberto, se houver), esperado por forma de pagamento do turno atual pra 3c, e as ações (`openOrResume`, `enterAdmin`, `exitToSelection`, `setClosingCountedCash`, `confirmCloseTurno`).
- `lib/ui/features/posto/views/open_posto_view.dart` — **novo**: 3a.
- `lib/ui/features/posto/views/monitor_posto_view.dart` — **novo**: 3b — reaproveita `ActiveRentalsCubit` (filtrado) e `showNewRentalSheet`/`showEndRentalDialog` já existentes.
- `lib/ui/features/posto/views/close_shift_view.dart` — **novo**: 3c.
- `lib/ui/features/admin_panel/view_models/admin_panel_state.dart` + `admin_panel_cubit.dart` — **novo**: total do dia, linhas por turno (toy/monitor/loc/bruto/status), trilha de locações encerradas hoje.
- `lib/ui/features/admin_panel/views/admin_panel_view.dart` — **novo**: 3d, tela cheia (`Navigator.push`, mesmo padrão de `BusinessSettingsView`).
- `lib/widgets/app_header.dart` — **alterado**: novo ícone (ex. `Icons.dashboard_outlined`) ao lado da engrenagem, abre `AdminPanelView`; header inteiro só aparece em modo admin (já é o único jeito de chegar no `HomeShell`), então nenhuma condicional nova de visibilidade é necessária ali.
- `lib/ui/features/rental/views/new_rental_sheet_view.dart` — **alterado**: quando aberta a partir de um posto (`context.read<PostoSessionCubit>().state.mode == PostoMode.monitor`), esconde o seletor de brinquedo e chama `submit(createdByMonitorName: ...)`.
- `lib/ui/features/rental/views/end_rental_dialog_view.dart` — **alterado**: botão de confirmar passa `actingMonitorName` lido de `PostoSessionCubit`.
- `lib/ui/features/rental/view_models/new_rental_cubit.dart` — **alterado**: `submit({String? createdByMonitorName})`.
- `lib/ui/features/rental/view_models/active_rentals_cubit.dart` — **alterado**: `confirmEnd({String? actingMonitorName})`.
- `main.dart` — **alterado**: cria/injeta `TurnoRepository` (+ `TurnoLocalService`, `load()` no bootstrap igual aos outros 2), adiciona `BlocProvider<PostoSessionCubit>`/`BlocProvider<AdminPanelCubit>` ao `MultiBlocProvider`, troca `home: const HomeShell()` por um `Builder`/`BlocBuilder<PostoSessionCubit,...>` que escolhe entre `OpenPostoView`/`MonitorPostoView`/`HomeShell`.
- `test/posto_monitor_painel_test.dart` — **novo**: cenários do spec.

## Modelo de dados / estado

```
Turno { id, toyId, monitorName, openedAt, closedAt (mutável, null=aberto), countedCash (mutável, null=aberto) }
Rental { ...campos atuais..., createdByMonitorName (String?, novo), finishedByMonitorName (String?, novo) }
```

`PostoSessionState` (Cubit, não domain model): `mode` (`none|monitor|admin`), `toyId?`, `monitorName?`, `turnoId?`, `turnoOpenedAt?`, `postos` (lista pra 3a: cada item = `Toy` + `Turno?` aberto), `closingExpectedByMethod` (`Map<PaymentMethod, double>`, só relevante em `monitor`/fechando), `closingCountedCashInput` (draft de texto de 3c).

`AdminPanelState`: `totalGrossToday`, `totalLocToday`, `turnRows` (uma por `Turno` de hoje: `toy`, `monitorName`, `locCount`, `gross`, `status` enum `aberto|fechadoOk|fechadoDivergente(diff)`), `trail` (locações com `status == done` e `endedAt` hoje, mais recente primeiro, com `finishedByMonitorName`).

Migração SQLite (`_version` 2): `ALTER TABLE rentals ADD COLUMN created_by_monitor_name TEXT` / `... finished_by_monitor_name TEXT`; `CREATE TABLE turnos (id TEXT PRIMARY KEY, toy_id TEXT NOT NULL, monitor_name TEXT NOT NULL, opened_at INTEGER NOT NULL, closed_at INTEGER, counted_cash REAL)`.

## Riscos / dependências

- **Nenhuma dependência de spec não implementada** — tudo local (SQLite já existente, spec 020), sem tocar backend (specs 022/001 continuam do jeito que estão, fora de escopo aqui, conforme decidido com o dono do produto).
- **Regra de não-quebra**: `HomeShell`/telas atuais continuam funcionando idênticas em modo admin — nenhum teste existente deveria quebrar, já que nenhum comportamento de tela já existente muda, só ganha 2 pontos de leitura opcional (`PostoSessionCubit`, sempre `null`/`none` nos testes que não o proveem — **atenção**: como o `home:` do `MaterialApp` passa a depender de `PostoSessionCubit`, todo teste de widget que hoje faz `pumpWidget(SonhoDeCriancaApp(...))` esperando cair direto no `HomeShell` precisa que o `PostoSessionCubit` comece em `mode: admin` nesses testes, ou vai cair na tela de abrir posto (3a) e quebrar — resolvido dando um construtor/parâmetro de teste que já nasce em modo admin (mesmo padrão de `RentalRepository.withDemoSeed` pra teste), nunca mudando o default de produção (que é sempre `none`).
- Migração de schema aditiva é de baixo risco (só `ADD COLUMN`/`CREATE TABLE`), mas precisa de teste cobrindo abrir um banco v1 existente e confirmar que os dados antigos sobrevivem.
- `PostoSessionCubit` ficando "grande" (session + lista de postos + cálculo de esperado) é aceito conscientemente — dividir mais cedo que isso seria abstração prematura pra uma feature nova ainda sem 2º consumidor do mesmo cálculo.

## Alternativas consideradas

- **Reaproveitar `ActiveRentalsCubit`/`NewRentalCubit` como instâncias separadas por posto** (uma instância nova por `toyId` toda vez que abre um posto) — descartado: o modo administrador precisa continuar vendo a lista global de locações ativas exatamente como hoje: manter a instância única global e filtrar na View é mais simples e não duplica a lógica de notificação/Pix/extend já testada.
- **`Turno`/sessão de posto persistidos em `SharedPreferences`** (sobreviver a restart do app sem passar por 3a de novo) — descartado pela decisão explícita do spec ("sessão não persiste entre reinícios"); o dado de negócio (`Turno` em si) persiste no SQLite, só a *sessão de quem está usando o app agora* não.
- **Cancelar locação virar evento de trilha** (precisaria de `RentalStatus.cancelled` em vez de exclusão) — fora de escopo explícito do spec; incluído aqui só pra registrar que foi considerado e descartado por ripple em `ReportCubit`/testes existentes.
