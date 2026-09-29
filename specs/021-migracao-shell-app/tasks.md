# Tasks: Migração — Shell do app (tab ativa, cabeçalho, nav)

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `AppTab` + `AppShellState` (Equatable, getters `kicker`/`screenTitle`) em `lib/ui/features/app_shell/view_models/app_shell_state.dart`.
- [x] T2 — `AppShellCubit` em `lib/ui/features/app_shell/view_models/app_shell_cubit.dart` — estado inicial `AppTab.home`, `setTab(AppTab)`.
- [x] T3 — `lib/state/app_state.dart`: remove `enum AppTab` local, reimporta/re-exporta de `app_shell_state.dart`. `tab`/`setTab`/`kicker`/`screenTitle` continuam existindo, inalterados.
- [x] T4 — `home_shell.dart`, `app_bottom_nav.dart`, `app_header.dart`: trocam `AppState` por `AppShellCubit`.
- [x] T5 — `main.dart`: registra `BlocProvider<AppShellCubit>`.
- [x] T6 — `test/app_shell_cubit_test.dart`: estado inicial, `setTab` muda `tab`, `kicker`/`screenTitle` corretos por aba.
- [x] T7 — Suíte completa rodada: 3 arquivos (`catalog_tickets_test.dart`, `design_v3_test.dart`, `report_view_test.dart`) usavam `state.setTab(...)` (AppState) só como atalho de navegação de UI — atualizados pra chamar `AppShellCubit.setTab` direto (mesmo mecanismo que `app_bottom_nav.dart` usa agora), sem alterar nenhum assert. Os outros ~15 arquivos que usam `AppState`/`AppTab` como fixture (sem depender de navegação de `View`) não precisaram mudar.
- [x] T8 — `flutter analyze` limpo.
- [x] T9 — `flutter test` completo, sem alterar nenhum assert existente ("All tests passed!").
- [x] T10 — Revisão manual dos critérios de aceite do `spec.md` + atualizar `specs/README.md` (linha 021 vira `Implemented`).

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.

**Nota final do roadmap de arquitetura em camadas**: com esta fatia, nenhuma `View`/widget de produção lê `AppState` direto — só os ~18 arquivos de teste que chamam seus métodos como atalho de setup (mantidos pela regra de não-quebra, ver "Fora de escopo" do `spec.md`).
