# Tasks: Migração — Painel do dia (Home)

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `HomeState` (Equatable) em `lib/ui/features/home/view_models/`.
- [x] T2 — `HomeCubit` — `_compute` replica as fórmulas de `AppState`, ticker de 1s, escuta `ToyRepository`/`RentalRepository`.
- [x] T3 — `HomeView` em `lib/ui/features/home/views/` — mover UI de `home_tab.dart`, trocar `AppState` por `HomeCubit`.
- [x] T4 — `AppState`: removidos `recentActivity`/`doneAll`/`doneToday`/`homeTotalToday`/`_startOfDay`.
- [x] T5 — `home_shell.dart`/`main.dart` atualizados. Removido `lib/screens/tabs/home_tab.dart`.
- [x] T6 — `test/home_cubit_test.dart`: totais/atividade recente/disponibilidade no seed padrão, sincronia com `AppState`.
- [x] T7 — `flutter analyze` limpo.
- [x] T8 — `flutter test` completo, sem alterar nenhum assert existente (93 testes — 88 anteriores + 5 novos —, todos verdes).
- [x] T9 — Revisão manual dos critérios de aceite do `spec.md` + atualizar `specs/README.md` (linha 019 vira `Implemented`).

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.

**Nota final do roadmap de locação**: com esta fatia, nenhuma `View` de tela lê `AppState` diretamente mais — só `home_shell.dart`/`app_bottom_nav.dart`/`app_header.dart` (navegação de aba/`tab`/`screenTitle`/`kicker`, nunca fez parte de nenhuma spec deste roadmap) e os ~30 arquivos de teste que chamam métodos de `AppState` como atalho de setup (mantidos pela regra de não-quebra).
