# Tasks: Catálogo via backend + sessão de dispositivo

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `secrets.example.json` (chaves `DEVICE_OPERATOR_USERNAME`/`DEVICE_OPERATOR_PASSWORD` sem valor) + `.gitignore` ganha `secrets.json`.
- [x] T2 — Operador `device` seedado em produção (`npm run seed:operator` no repo backend).
- [x] T3 — `lib/data/repositories/auth_repository.dart`: `deviceToken` + `loginDevice()` (lê `String.fromEnvironment`, só em memória, falha não propaga).
- [x] T4 — `lib/data/services/toy_remote_service.dart` — `load({token})`, `create/update/remove({token})` via `ApiClient`.
- [x] T5 — `lib/data/repositories/toy_repository.dart` reescrito: `load()` com fallback silencioso + retry único via `loginDevice()` em 401 (cenário 4); `addNew`/`updatePrice`/`updateBlockMinutes`/`remove` `Future`, otimista com reversão em falha.
- [x] T6 — `lib/widgets/auth_gate.dart` — `ensureOperatorSession(BuildContext)`, extraído de `openBusinessSettingsScreen`.
- [x] T7 — `lib/widgets/modal_launchers.dart`: `openBusinessSettingsScreen` usa o gate extraído (mesmo comportamento); `showAddToySheet` ganha o gate antes de abrir a sheet.
- [x] T8 — `lib/ui/features/catalog/view_models/toy_catalog_cubit.dart`: `addToy`/`updatePrice`/`updateBlockMinutes`/`removeToy` viram `async`, repassam exceção pra View; ganhou `refreshCatalog()`.
- [x] T9 — `lib/ui/features/catalog/views/catalog_view.dart`: `initState` com `addPostFrameCallback` chamando `refreshCatalog()`; `_MiniField` ganhou `didUpdateWidget` (sincroniza quando não focado — reversão ou edição em outro aparelho); commit e `_confirmRemove` `async` com reversão + `SnackBar` (ação "Entrar" em `ApiUnauthorizedException`, mensagem do servidor em `ApiException`).
- [x] T10 — `lib/ui/features/catalog/views/add_toy_sheet_view.dart`: `_submit` `async` (com guarda `_submitting` + spinner no botão), só fecha em sucesso.
- [x] T11 — `lib/state/app_state.dart`: remove `addToy`/`updateToyPrice`/`updateToyBlock`/`removeToy`/`toyHasRentals` (dead code, sem chamador desde specs 012/015).
- [x] T12 — `lib/main.dart`: `loginDevice()` + `toyRepository.load()` em background (`unawaited`, depois do `Future.wait` de boot) — não bloqueiam o primeiro frame (cenário 4); injeta `ToyRemoteService`/`ToyRepository` novos.
- [x] T13 — `test/fakes/fake_toy_backend.dart` (espelha `fake_business_settings.dart`, fake permissivo pra uso geral). Sessão de dispositivo mockada ficou como uma classe `_FakeDeviceAuth` dentro de `toy_repository_test.dart` (mais simples que um fake de login de dispositivo completo, já que só precisa expor `deviceToken` pronto).
- [x] T14 — teste cenário 1 — `toy_repository_test.dart`: `load()` lê o catálogo via `deviceToken`, sem sessão de operador real.
- [x] T15 — teste cenário 2 — `toy_repository_test.dart`: dois `ToyRepository` compartilhando o mesmo backend fake, um cria, o outro vê ao `load()`.
- [x] T16 — teste cenário 3 — `toy_repository_test.dart`: `addNew`/`updatePrice` sem sessão real lançam `ApiUnauthorizedException`; com sessão, funcionam. Guarda de login em si (`ensureOperatorSession`) coberta via `login_flow_test.dart` (spec 024, mesma função).
- [x] T17 — teste cenário 4 — `toy_repository_test.dart`: sem `deviceToken` configurado e com backend fora do ar, `load()` mantém o catálogo em cache sem lançar.
- [x] T18 — teste cenário 5 — `toy_repository_test.dart`: `remove()` com brinquedo bloqueado devolve a mensagem exata do backend (409) e reverte a remoção otimista.
- [x] T19 — regressão: `toy_catalog_cubit_test.dart` (id não é mais `custom_*`), `catalog_tickets_test.dart` (`AppState.addToy` removido → chama `ToyCatalogCubit` direto), `design_v3_test.dart`/`modal_launchers_test.dart` (injetam `toyRepository`/`authRepository` fakes — sem isso cairiam no backend real), `persistence_round_trip_test.dart` (os 2 testes de `Toy` foram removidos — `ToyRepository` não persiste mais em SQLite). Suíte inteira verde (148 testes), rodada 2x seguidas sem flake novo.
- [x] T20 — `flutter analyze` limpo (`lib`, `test`, `integration_test`) + `flutter test` completo (148/148) + revisão manual dos critérios de aceite do `spec.md` + `specs/README.md` linha 025 = `Implemented`.

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.

**Não** faz parte desta fatia: `RentalRepository` via HTTP (spec seguinte — reaproveita `deviceToken` pra criar/estender/cancelar, exige sessão real só em `finish`). Depois do merge: recriar o catálogo em produção via "Novo brinquedo" no app (ver `plan.md`, "Riscos") — produção está com `toys` vazio.
