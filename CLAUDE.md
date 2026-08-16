# Sonho de Criança

App Flutter de aluguel de brinquedos (Toy, Rental). State via `provider` (`lib/state/app_state.dart`).

## Spec Driven Development — obrigatório

Antes de codar feature nova ou mudar comportamento visível: ler [specs/README.md](specs/README.md) e [specs/constitution.md](specs/constitution.md).

Fluxo curto: `specs/NNN-nome/spec.md` (aprovado) → `plan.md` → `tasks.md` → implementação. Templates em `specs/_templates/`.

Bugfix mecânico e chore não precisam de spec.

## Estrutura

- `lib/models/` — Toy, Rental (dados puros).
- `lib/state/app_state.dart` — única fonte de verdade.
- `lib/screens/` — telas.
- `lib/widgets/` — dialogs, sheets, componentes.
- `lib/theme/` — `AppColors`, `AppTheme`.
- `lib/test_keys.dart` — chaves centralizadas p/ testes.

## Antes de fechar tarefa

- `flutter analyze` limpo.
- Teste em `test/` cobrindo comportamento novo/alterado.
