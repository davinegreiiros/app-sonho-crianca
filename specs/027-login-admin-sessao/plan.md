# Plan: Login do administrador na entrada + sessão única + logout

Referência: `spec.md` nesta pasta.

## Camadas

- **Service** — `lib/data/services/auth_session_local_service.dart` (novo): `read`/`write`/`delete` do JSON da sessão em `SharedPreferences`, chave `sonho_de_crianca_session` (mesma chave usada antes no `flutter_secure_storage`).
- **Repository** — `AuthRepository`:
  - troca `FlutterSecureStorage` por `AuthSessionLocalService`;
  - remove `loginDevice`/`deviceToken`;
  - `isLoggedIn`/`token`/`currentOperator` consideram o `exp` do JWT (decodificado só o payload, sem verificar assinatura; token sem `exp` legível = validade desconhecida, decide o backend);
  - `restoreSession` descarta sessão vencida/corrompida e apaga do storage;
  - `clock` injetável pra teste.
- **Repository** — `ToyRepository.load`/`RentalRepository.load`: usam `token`; sem token, retornam sem chamar a rede; 401 → `authRepository.logout()`. Escritas (`addNew`/`extend`/`cancel`/`finish`, CRUD de brinquedo) também fazem logout em 401 antes de relançar.
- **Service** — `RentalRemoteService.finish` manda `finalPrice` quando vier (tempo corrido; backend aceita desde `548bb58`). Antes o valor final só existia no app, o backend gravava R$ 0.
- **Boot** — `main.dart`: sem `loginDevice`; dispara `load()` de catálogo/locações no boot e sempre que o token muda pra um novo não-nulo (login).
- **UI**:
  - `auth_gate.dart`: `loginActionFor(context)` (resolve `NavigatorState`/`AuthRepository` antes, pra ação de SnackBar).
  - `open_posto_view.dart`: `_enterAdmin` usa `ensureOperatorSession` — login só sem sessão válida.
  - `app_header.dart`: `_AdminMenu` (`PopupMenuButton`) com "Voltar para os postos" (`PostoSessionCubit.exitToSelection`) e "Sair da conta" (`confirmAdminLogout` em `modal_launchers.dart`: diálogo → `logout()` → `exitToSelection()`).
  - `rental_action_error.dart`, `catalog_view.dart`: SnackBar "Entrar" usa `loginActionFor`.
- **Config**: remove `flutter_secure_storage` do `pubspec.yaml`, `secrets.example.json`, `--dart-define-from-file` do `launch.json`; `android:allowBackup="false"`.

## Segurança

Ver "Trade-off aceito" no `spec.md`. Nada de token em log: o `debugPrint` de falha de `RentalRepository.load` passou a imprimir só o tipo do erro. Nenhuma senha é persistida. Permissão nova: nenhuma.

## Riscos

- Aparelho atualizado perde a sessão antiga (estava no Keystore/Keychain): o administrador loga de novo uma vez. Aceito.
- Posto sem sessão (após logout) fica só com cache/seed até alguém logar — comportamento esperado, documentado no `spec.md`.
- iOS mantém o `UserDefaults` em backup do iCloud/iTunes; o token expira em 12h, o que limita o impacto. Não há equivalente simples ao `allowBackup` sem mover o arquivo; fica registrado.
