# Tasks: Migração de arquitetura para camadas — fundação

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — Adicionar `flutter_bloc` e `equatable` ao `pubspec.yaml`, `flutter pub get`.
- [x] T2 — Criar esqueleto de pastas: `lib/data/repositories/`, `lib/data/services/`, `lib/domain/models/`, `lib/domain/use_cases/`, `lib/ui/core/`, `lib/ui/features/` (`.gitkeep` nas que ainda ficam vazias).
- [x] T3 — Mover `lib/models/toy.dart`, `rental.dart`, `business_settings.dart` para `lib/domain/models/`, ajustando o import interno de `toy.dart` (`../theme/app_colors.dart` → `../../theme/app_colors.dart`). Remover `lib/models/` vazia.
- [x] T4 — Atualizar imports em `lib/` (`app_state.dart`, `business_settings_screen.dart`, tabs, widgets) do caminho antigo pro novo.
- [x] T5 — Atualizar imports em `test/` (`package:sonho_de_crianca/models/...` → `package:sonho_de_crianca/domain/models/...`).
- [x] T6 — `flutter analyze` limpo.
- [x] T7 — Suíte de testes (`flutter test`) passando sem alterar asserts (40 testes, todos verdes).
- [x] T8 — Revisão manual dos critérios de aceite do `spec.md` + atualizar `specs/README.md` (status da linha 010 vira `Implemented`).

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
