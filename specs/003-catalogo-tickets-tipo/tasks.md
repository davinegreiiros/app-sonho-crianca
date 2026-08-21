# Tasks: Catálogo — tickets + tipo obrigatório

Referência: [spec.md](spec.md) + [plan.md](plan.md).

- [x] T1 — `ToyCategory` enum + label pt-BR em `toy.dart`, `Toy.category` obrigatório, `copyWith` propaga, seeds atualizados
- [x] T2 — `AppState.addToy` recebe `category`
- [x] T3 — `AddToySheet`: seletor de categoria, obrigatório em `_valid`
- [x] T4 — `catalog_tab.dart`: `_AvailabilityTickets` (ticket serrilhado, limite 6 + `+N`)
- [x] T5 — `catalog_tab.dart`: tag de tipo no card, `_contentHeight` 150→180
- [x] T6 — testes de widget: `test/catalog_tickets_test.dart` (livre/misto/todos em uso/acima do limite/tag/validação categoria) — 6 testes, todos passando
- [x] T7 — `flutter analyze` limpo, `flutter test` (13 testes) passando, evidência visual em `evidence/catalogo-tickets.png`

Assets novos de ilustração seguem bloqueados (ver `spec.md`) — não impediram o resto.

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`. Se algo quebrar no meio, parar ali (regra de não-quebra da constitution), não emendar.
