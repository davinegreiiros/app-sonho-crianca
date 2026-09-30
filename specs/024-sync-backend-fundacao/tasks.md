# Tasks: Sync com backend — fundação (login de operador + BusinessSettings via HTTP)

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `pubspec.yaml`: `http: ^1.2.2`, `flutter_secure_storage: ^9.2.2`.
- [x] T2 — `lib/domain/models/operator.dart` — `Operator` (id, name, username).
- [x] T3 — `lib/data/services/api_exceptions.dart` (`ApiUnauthorizedException`, `ApiNetworkException`, `ApiException`) + `lib/data/services/api_client.dart` (base URL com override `--dart-define`, timeout 10s, header `Authorization` opcional, mapeamento de erro).
- [x] T4 — `lib/data/repositories/auth_repository.dart` — `login`, `logout`, `restoreSession`, `currentOperator`/`isLoggedIn`/`token`, persistência via `flutter_secure_storage`.
- [x] T5 — `lib/data/services/business_settings_remote_service.dart` — `load()`/`save()` via `ApiClient` (`GET`/`PUT /api/business-settings`).
- [x] T6 — `lib/data/repositories/business_settings_repository.dart` — troca o `Service` interno, ganha `BusinessSettingsSyncStatus` (idle/loading/loaded/unauthorized/networkError), 401 em qualquer chamada dispara `AuthRepository.logout()`.
- [x] T7 — `lib/ui/features/auth/view_models/login_state.dart` + `login_cubit.dart` (idle/loading/credenciaisInvalidas/semConexao/sucesso).
- [x] T8 — `lib/ui/features/auth/views/login_view.dart` — campos usuário/senha, mensagens de erro distintas por tipo, `TestKeys` novas em `lib/test_keys.dart`.
- [x] T9 — `lib/ui/features/business_settings/view_models/business_settings_state.dart` (+`status`) e `business_settings_cubit.dart` (repassa status do Repository, `refresh()` novo).
- [x] T10 — `lib/ui/features/business_settings/views/business_settings_view.dart` — reage a `status`: `unauthorized` sai da tela com `BusinessSettingsExitReason.sessionExpired`, `networkError` mostra aviso de conectividade inline (distinto de erro de credencial). Busca (`refresh()`) disparada via `addPostFrameCallback` — chamar direto no `initState` notificava em pleno build (bug pego pelos próprios testes).
- [x] T11 — `lib/widgets/modal_launchers.dart`: `openBusinessSettingsScreen` ganha a guarda de login (checa `AuthRepository.isLoggedIn`, empurra `LoginView` antes se preciso; mostra snackbar de "sessão expirada" se voltar com esse motivo).
- [x] T12 — `lib/main.dart`: injeta `AuthRepository` (chama `restoreSession()` no boot — só storage local, sem rede); `BusinessSettingsRepository` não carrega mais no boot (`Future.wait`), só quando a `View` abre (`refresh()`), pra não atrasar todo cold start com uma chamada de rede que ninguém pediu ainda.
- [x] T13 — teste cenário 1/2/4 — sem sessão entra em Configurações → login; login ok → sessão persiste e sobrevive "restart" (`test/login_flow_test.dart`, `test/auth_repository_test.dart`).
- [x] T14 — teste cenário 3 — credenciais erradas → mensagem de erro específica, tela continua utilizável (`test/login_cubit_test.dart`, `test/login_flow_test.dart`).
- [x] T15 — teste cenário 5 — 401 em chamada de `BusinessSettings` marca `unauthorized` e desloga (`test/business_settings_cubit_test.dart`).
- [x] T16 — teste cenário 6 — sem rede (`MockClient` lançando) → aviso de conectividade, distinto do erro de credencial/sessão (`test/login_cubit_test.dart`, `test/business_settings_cubit_test.dart`).
- [x] T17 — teste cenário 7 — duas instâncias de `BusinessSettingsRepository` compartilhando o mesmo backend fake: uma salva, a outra lê o valor novo (`test/business_settings_cubit_test.dart`).
- [x] T18 — teste cenário 8 — `openBusinessSettingsScreen` sem sessão sempre passa pelo login primeiro (`test/login_flow_test.dart`); mesma função serve `app_header.dart` e `end_rental_dialog_view.dart`, sem branch por chamador — não precisa de teste duplicado pro segundo caller.
- [x] T19 — regressão: 5 testes pré-existentes que passavam por Configurações precisaram de fake de sessão/backend (`design_v3_test.dart`, `full_app_journey_test.dart`, `pix_flow_test.dart` ×2, `business_settings_cubit_test.dart`) — `AppState.businessSettings`/`end_rental_dialog_view.dart`/`pix_qr_sheet_view.dart` continuam funcionando sem tocar HTTP diretamente. Suíte inteira verde (135 testes).
- [ ] T20 — smoke-test manual em dispositivo/emulador real — **não executado nesta sessão** (sem device conectado neste ambiente). Pendente: `flutter_secure_storage` gravando/lendo de verdade + login contra `https://sonho-de-crianca-backend.vercel.app` com um operador de teste (`npm run seed:operator` no repo backend, se ainda não tiver um).
- [x] T21 — `flutter analyze` limpo + `flutter test` completo (135/135) + revisão manual dos critérios de aceite do `spec.md` + `specs/README.md` linha 024 = `Implemented`.

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.

**Não** faz parte desta fatia: `ToyRepository`/`RentalRepository` via HTTP (specs seguintes) e reconciliar `Turno.monitorName` com `Operator` real (mesma spec futura, quando `Rental` migrar).
