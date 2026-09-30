# Tasks: Migração — Configurações do negócio

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `BusinessSettingsLocalService` (`lib/data/services/`): `load()`/`save()` sobre `SharedPreferences`, mesmas 3 chaves de hoje.
- [x] T2 — `BusinessSettingsRepository` (`lib/data/repositories/`): `settings`, `load()`, `update()`, `ChangeNotifier` + `_disposed`.
- [x] T3 — `BusinessSettingsState` (Equatable) + `BusinessSettingsCubit` (`lib/ui/features/business_settings/view_models/`).
- [x] T4 — `BusinessSettingsView` (`lib/ui/features/business_settings/views/`) — mover UI de `business_settings_screen.dart`, trocar `AppState` por `BusinessSettingsCubit`.
- [x] T5 — `AppState`: `businessSettingsRepository` opcional no construtor, `businessSettings`/`updateBusinessSettings` viram proxy, remove persistência própria e `_loadBusinessSettings`.
- [x] T6 — `main.dart`: instância única de `BusinessSettingsRepository` (via `ChangeNotifierProvider`, não `Provider` simples — `provider` recusa expor um `ChangeNotifier` como `Provider` puro), provida pro `AppState` e pro `BlocProvider<BusinessSettingsCubit>`.
- [x] T7 — `modal_launchers.dart`: `openBusinessSettingsScreen` usa `BusinessSettingsView`. Removido `lib/screens/business_settings_screen.dart` e os `.gitkeep` que deixaram de fazer sentido.
- [x] T8 — `test/business_settings_cubit_test.dart`: estado inicial, `save()` persiste e emite estado novo, sem `WidgetTester` (usa `bloc_test`, adicionado como dev dependency).
- [x] T9 — `flutter analyze` limpo.
- [x] T10 — `flutter test` completo, sem alterar asserts existentes (44 testes — 40 anteriores + 4 novos —, todos verdes).
- [x] T11 — Revisão manual dos critérios de aceite do `spec.md` + atualizar `specs/README.md` (linha 011 vira `Implemented`).

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
