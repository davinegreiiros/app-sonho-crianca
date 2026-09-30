# Plan: Sync com backend — fundação (login de operador + BusinessSettings via HTTP)

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Mesmo espírito strangler-fig da [011-migracao-configuracoes-negocio](../011-migracao-configuracoes-negocio/plan.md): troca só a camada `Service` por baixo de `BusinessSettingsRepository`, mantendo a interface pública (`settings`, `load()`, `update()`, `ChangeNotifier`) intacta — `AppState.businessSettings` (proxy legado, ainda em uso por `end_rental_dialog_view.dart`/`pix_qr_sheet.dart`) e `BusinessSettingsCubit` continuam funcionando sem mudar uma linha nesses dois consumidores. Só o `Repository` ganha um jeito de sinalizar "precisa logar"/"sem rede" além do valor — os consumidores antigos ignoram esse sinal novo, os novos (Cubit/View de Configurações) o usam.

1. **Domain model `Operator`** — espelha `id`/`name`/`username` do backend (nunca senha/hash).
2. **`ApiClient`** (`lib/data/services/`) — fino wrapper sobre `package:http`: base URL (const, override por `--dart-define=API_BASE_URL=...` pra apontar num `next dev` local), timeout de 10s, serialização JSON, injeta `Authorization: Bearer <token>` quando um token é passado, e mapeia resposta não-2xx em exceções tipadas (`ApiUnauthorizedException` pro 401, `ApiNetworkException` pra timeout/sem conexão, `ApiException` genérica com status pro resto) — nenhum `Cubit`/`View` faz `http.get` direto.
3. **`AuthRepository`** (novo) — dono da sessão: `login(username, password)` chama `POST /api/auth/login` via `ApiClient` (sem token), guarda `{token, operator}` em `flutter_secure_storage` e em memória, expõe `currentOperator`/`isLoggedIn`/`token` (getter síncrono, lido pelos outros Repositories na hora de montar a chamada) e `logout()`. `restoreSession()` lê o storage uma vez no boot (`main.dart`, antes do `runApp`, mesmo padrão de carregamento assíncrono que `AppState`/`BusinessSettingsRepository.load()` já usam).
4. **`BusinessSettingsRepository`** — troca `BusinessSettingsLocalService` por `BusinessSettingsRemoteService` (novo, mesma forma `load()`/`save()`, por baixo chama `GET`/`PUT /api/business-settings` via `ApiClient` usando o token do `AuthRepository`). `Repository` ganha um `BusinessSettingsSyncStatus` (`idle`/`loading`/`loaded`/`unauthorized`/`networkError`) notificado junto com `settings` — `settings` nunca lança, sempre devolve o último valor conhecido (igual hoje).
5. **Guarda de login centralizada** — `openBusinessSettingsScreen` (`lib/widgets/modal_launchers.dart`) é o único ponto de navegação pra `BusinessSettingsView` (usado por `app_header.dart` e pelo atalho de Pix em `end_rental_dialog_view.dart`, cenário 8 da spec): antes de empurrar a tela, checa `AuthRepository.isLoggedIn`; se não, empurra `LoginView` primeiro e só entra em `BusinessSettingsView` se o login for concluído (volta sem abrir nada se o operador cancelar).
6. **Sessão expirada em uso** — `BusinessSettingsRepository`/`ApiClient` reconhecem 401 a qualquer momento (não só no load inicial): `AuthRepository.logout()` é chamado e a `View` reage ao `BusinessSettingsSyncStatus.unauthorized` navegando de volta pro login com aviso.

## Arquivos afetados

- `lib/domain/models/operator.dart` — novo: `Operator` (id, name, username).
- `lib/data/services/api_client.dart` — novo: wrapper HTTP (ver acima). Exceções em `lib/data/services/api_exceptions.dart`.
- `lib/data/services/business_settings_remote_service.dart` — novo: sucessor de `business_settings_local_service.dart` (substituído, não deletado ainda — só desconectado da injeção em `main.dart`; mantém o arquivo local como referência/rollback até a spec fechar).
- `lib/data/repositories/auth_repository.dart` — novo (`ChangeNotifier`, mesmo padrão dos outros Repositories).
- `lib/data/repositories/business_settings_repository.dart` — alterado: recebe `BusinessSettingsRemoteService` + `AuthRepository` (token), ganha `BusinessSettingsSyncStatus`.
- `lib/ui/features/auth/view_models/login_cubit.dart`, `login_state.dart` — novo.
- `lib/ui/features/auth/views/login_view.dart` — novo.
- `lib/ui/features/business_settings/view_models/business_settings_state.dart` — alterado: ganha campo `status` (additive, `props` atualizado).
- `lib/ui/features/business_settings/view_models/business_settings_cubit.dart` — alterado: repassa `status` do Repository pro State.
- `lib/widgets/modal_launchers.dart` — alterado: `openBusinessSettingsScreen` ganha a guarda de login (item 5 acima).
- `lib/main.dart` — alterado: injeta `AuthRepository` (chama `restoreSession()` no boot, mesmo padrão de `BusinessSettingsRepository.load()`), passa pro `BusinessSettingsRepository`.
- `pubspec.yaml` — `http: ^1.2.2`, `flutter_secure_storage: ^9.2.2` (dependências novas — ver "Dúvidas em aberto" #2 do spec.md, já aceitas).
- `test/auth_repository_test.dart`, `test/business_settings_repository_test.dart`, `test/login_cubit_test.dart` — novos/alterados: `ApiClient` injetado com `package:http/testing.dart` (`MockClient`) — sem mockito/mocktail novo, sem bater no backend real.

## Modelo de dados / estado

- `Operator` (domain model novo): `{ id, name, username }` — sem `passwordHash`, espelha o contrato do backend (`specs/001-fundacao-auth-crud/spec.md` do repo `sonho-de-crianca-backend`).
- `BusinessSettings` (domain model) — inalterado, mesmo shape; só a origem do dado muda (backend em vez de `SharedPreferences`).
- Estado novo — `BusinessSettingsSyncStatus` (enum: `idle`, `loading`, `loaded`, `unauthorized`, `networkError`) e `LoginState` (Cubit: `idle`, `loading`, `credenciaisInvalidas`, `semConexao`, `sucesso`) — envelope de UI, não domain model.
- Sessão persistida (`flutter_secure_storage`): `{ token: String, operator: {id, name, username} }` serializado, uma única chave.

## Riscos / dependências

- Depende do backend (`sonho-de-crianca-backend`, spec `001-fundacao-auth-crud`) estar no ar — já está (`Implemented`, produção em `https://sonho-de-crianca-backend.vercel.app`).
- `end_rental_dialog_view.dart` e `pix_qr_sheet_view.dart` continuam lendo `BusinessSettingsCubit`/`AppState.businessSettings` sem mudança — risco de regressão é baixo justamente por isso (mesma interface), mas cenário 8 do spec (login bloqueando o atalho de Pix pro monitor) é uma mudança de comportamento real, já validada com o dono do produto na aprovação da spec.
- `flutter_secure_storage` no Android usa `EncryptedSharedPreferences`/Keystore — sem configuração extra esperada, mas primeira vez rodando no dispositivo físico/emulador vale conferir (`tasks.md` ganha uma task de smoke-test manual, não só teste automatizado, já que storage seguro não roda igual em todo ambiente de CI).
- Zero-breakage (constitution.md): qualquer teste hoje verde que dependa de `BusinessSettingsRepository` (`business_settings_cubit_test.dart`) precisa continuar passando — a troca de `Service` é interna, ele deve seguir funcionando com um fake em memória sem precisar saber de HTTP.

## Alternativas consideradas

- **`dio` em vez de `package:http`.** Descartado — `dio` traz interceptors/cancel tokens que esta fatia não precisa; `package:http` + um wrapper fino (`ApiClient`) resolve timeout/header/erro tipado sem dependência mais pesada, mesma filosofia da constitution de evitar dependência sem necessidade comprovada (`freezed` foi descartado pelo mesmo motivo na 010).
- **`SharedPreferences` pro token, sem `flutter_secure_storage`.** Descartado — JWT é credencial de sessão (12h), não config; guardar em texto plano no mesmo lugar que hoje guarda `merchantName` é um passo atrás de segurança justo na spec que introduz rede pela primeira vez (constitution.md, seção Segurança: "nenhum JWT/senha de operador em log" — em storage não-cifrado o risco é análogo se o aparelho for comprometido).
- **Login obrigatório em qualquer entrada do app (não só Configurações).** Descartado nesta fatia — quebraria o fluxo de posto (spec 023, monitor sem conta) inteiro de uma vez, não só o atalho de Pix; virou cenário 8 + decisão registrada, não isso.
- **Deixar o atalho de Pix (`end_rental_dialog_view.dart`) aberto sem login, só a tela via admin panel/`app_header` exigindo.** Descartado na aprovação da spec — daria dois comportamentos diferentes pra mesma `BusinessSettingsView` dependendo de quem chamou, mais estado pra rastrear, e o backend exige JWT pra escrever de qualquer jeito (não dava pra salvar sem token nesse caminho mesmo se a UI deixasse entrar).
