# Tasks: Posto do monitor + fechamento de turno + painel administrativo

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `lib/domain/models/turno.dart` (modelo `Turno`) + `lib/domain/models/rental.dart` ganha `createdByMonitorName`/`finishedByMonitorName`.
- [x] T2 — `lib/data/services/app_database.dart`: `_version` → 2, colunas novas em `rentals`, tabela `turnos`, `onUpgrade` aditivo. `lib/data/services/rental_local_service.dart` lê/grava as 2 colunas novas. `lib/data/services/turno_local_service.dart` novo (CRUD `turnos`).
- [x] T3 — `lib/data/repositories/turno_repository.dart` novo (`openTurnoFor`, `open`, `close`, trava de 1 turno aberto por `toyId`). `lib/data/repositories/rental_repository.dart`: `addNew`/`finish` ganham os parâmetros de autoria opcionais.
- [x] T4 — `PostoSessionState`/`PostoSessionCubit` (`lib/ui/features/posto/view_models/`): sessão + lista de postos (3a) + cálculo do esperado do turno atual (3c).
- [x] T5 — `OpenPostoView` (3a): lista de postos livre/ocupado, campo de nome, entrar/retomar, "Entrar como administrador".
- [x] T6 — `MonitorPostoView` (3b): locações ativas do `toyId` do posto (filtra `ActiveRentalsCubit.state.activeRentals`), "Colocar criança" (`showNewRentalSheet` com brinquedo travado), rodapé com bruto do turno, ação "Encerrar turno" → `CloseShiftView`.
- [x] T7 — `lib/ui/features/rental/views/new_rental_sheet_view.dart` (esconde seletor de brinquedo + passa `createdByMonitorName` quando `mode == monitor`) e `lib/ui/features/rental/views/end_rental_dialog_view.dart`/`pix_qr_sheet_view.dart` (passam `actingMonitorName`); `NewRentalCubit.submit`/`ActiveRentalsCubit.confirmEnd` recebem os parâmetros novos.
- [x] T8 — `CloseShiftView` (3c): esperado por forma de pagamento, campo de dinheiro contado, diferença colorida, confirmar fecha o `Turno` (`PostoSessionCubit.confirmCloseTurno`) e volta pra 3a.
- [x] T9 — `AdminPanelState`/`AdminPanelCubit` (`lib/ui/features/admin_panel/view_models/`): total do dia, linhas por turno, trilha de locações encerradas hoje.
- [x] T10 — `AdminPanelView` (3d) + novo ícone em `lib/widgets/app_header.dart` que abre ela (`Navigator.push`, mesmo padrão de Configurações).
- [x] T11 — wiring em `main.dart`: `TurnoRepository`/`TurnoLocalService` no bootstrap, `BlocProvider<PostoSessionCubit>`/`BlocProvider<AdminPanelCubit>`, `home:` do `MaterialApp` decide entre `OpenPostoView`/`MonitorPostoView`/`HomeShell` a partir de `PostoSessionCubit.state.mode`. Parâmetro `startInPostoAdminMode` pro `SonhoDeCriancaApp` nascer em modo admin (ver "Riscos" do `plan.md`) — default de produção continua `none`.
- [x] T12 — Auditoria de todo teste de widget existente que faz `pumpWidget(SonhoDeCriancaApp(...))` — os 9 arquivos afetados ajustados pra usar `startInPostoAdminMode: true` onde precisavam continuar caindo direto no `HomeShell`.
- [x] T13 — Teste novo `test/posto_monitor_painel_test.dart`: abrir posto livre cria turno e trava o brinquedo em 3b; tocar posto ocupado retoma o mesmo turno (não duplica); fechamento calcula esperado/diferença certo; painel soma faturamento e lista turnos de hoje; migração de schema v1→v2 não perde dado.
- [x] T14 — `flutter analyze` limpo (0 issues) + `flutter test` completo (120 testes, 0 falhas) + revisão manual dos critérios de aceite do `spec.md` + `specs/README.md` (linha 023 vira `Implemented`). SDK do ambiente foi atualizado pra 3.44.6 (`C:\development\Versions_flutter\3.44.6`) pra rodar isso — troca do PATH de sistema pendente por falta de privilégio admin na sessão, ver aviso separado.
- [x] T15 — Correções pós-review (Codex, PR #5): esperado do turno (3c) e linha do turno (3d) só contam locação encerrada pelo monitor do próprio turno (`finishedByMonitorName`); fechar turno exige contagem de dinheiro válida (0 explícito vale); trilha (3d) passa a ter também os eventos de criação (`startedAt`/`createdByMonitorName`), como o `spec.md` já pedia — T9 tinha implementado só encerramento.

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
