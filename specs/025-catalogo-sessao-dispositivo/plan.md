# Plan: Catálogo via backend + sessão de dispositivo

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Mesmo strangler-fig da 024: troca o `Service` por baixo de `ToyRepository`, interface pública minimamente alterada (métodos de escrita viram `Future`, leitura continua síncrona via `toys` getter). A parte nova é a sessão de dispositivo, construída aqui mas pensada pra `RentalRepository` (spec seguinte) reaproveitar sem mudança.

1. **`AuthRepository` ganha uma segunda sessão** — `deviceToken` (separado de `token`, a sessão de operador real já existente). `loginDevice()`: chama `POST /api/auth/login` com usuário/senha de dispositivo (constantes de compilação, nunca digitadas, nunca commitadas — ver item 2), guarda só em memória (sem `flutter_secure_storage`: é uma credencial da instalação do app, não de uma pessoa; relogar a cada boot é barato e mais simples que persistir+renovar). Falha (rede, 401) não derruba o boot — fica sem `deviceToken`, `ToyRepository.load()` cai no fallback do cenário 4.
2. **Credencial de dispositivo**: `String.fromEnvironment('DEVICE_OPERATOR_USERNAME')` / `'DEVICE_OPERATOR_PASSWORD')`, sem default (vazio = não configurado, `loginDevice()` não tenta nada). Fornecida via `--dart-define-from-file=secrets.json`, arquivo **não commitado** (`.gitignore`), com `secrets.example.json` documentando as chaves sem valor — mesma régua de `.env.example` no backend. Operador `device` seedado uma vez em produção via `npm run seed:operator` (repo backend).
3. **`ToyRemoteService`** (novo, espelha `BusinessSettingsRemoteService`): `load({token})` → `GET /api/toys` (token de dispositivo); `create/update/remove({token})` → `POST/PATCH/DELETE /api/toys` (token de operador real).
4. **`ToyRepository`** reescrito:
   - `load()` — usa `authRepository.deviceToken`. Sucesso substitui `_toys`; falha (rede, 401, sem `deviceToken` configurado) **não propaga erro nenhum** — mantém o que já estava em memória (seed inicial ou último fetch bom), só loga (cenário 4: catálogo é o fluxo principal do posto, não pode travar por conectividade).
   - `addNew`/`updatePrice`/`updateBlockMinutes`/`remove` — viram `Future<...>`, usam `authRepository.token` (operador real). Sem sessão ou 401 → deixa `ApiUnauthorizedException` subir (mesmo padrão de `AuthRepository.login` — quem chama decide a UI). Continuam otimistas (atualiza `_toys` e notifica antes do `await`), mas agora com reversão: se a chamada falhar, desfaz a atualização local e re-lança, pra `_toys` nunca divergir silenciosamente do backend.
5. **Guarda de login reutilizável** — extrai `ensureOperatorSession(BuildContext)` de dentro de `openBusinessSettingsScreen` pra `lib/widgets/auth_gate.dart`: checa `AuthRepository.isLoggedIn`, empurra `LoginView` se preciso, devolve `true`/`false`. `openBusinessSettingsScreen` passa a chamar essa função; `showAddToySheet` (novo brinquedo) ganha a mesma chamada antes de abrir a sheet.
6. **Edição inline no grid** (`catalog_view.dart`, `_MiniField`) — já comita só no blur (`onFocusChange`), não por tecla: nenhuma mudança de debounce necessária. `_updatePrice`/`_updateBlockMinutes` (novos wrappers na View) ficam `async`, capturam `ApiUnauthorizedException`/`ApiNetworkException`/`ApiException`: reverte o campo pro valor anterior do `Toy` e mostra `SnackBar` (`ApiUnauthorizedException` ganha ação "Entrar" que abre `LoginView`; os outros só mostram `e.message`).
7. **Remover brinquedo** — `_confirmRemove` vira `async`; 409 do backend (`Rental` vinculado) chega como `ApiException` com a mensagem pronta do servidor — `SnackBar` usa `e.message` direto, não hardcoda mais o texto.
8. **`CatalogView`** ganha `initState` com `addPostFrameCallback` chamando `context.read<ToyCatalogCubit>().refreshCatalog()` (novo método, delega a `_toyRepository.load()`) — mesmo padrão/mesmo motivo do `BusinessSettingsView` (evita notificar em pleno build).
9. **Limpeza**: `AppState.addToy`/`updateToyPrice`/`updateToyBlock`/`removeToy`/`toyHasRentals` não têm mais nenhum chamador real (`catalog_view.dart`/`add_toy_sheet_view.dart` já usam só `ToyCatalogCubit` desde as specs 012/015) — remover em vez de converter pra `Future` sem ninguém `await`-ar.

## Arquivos afetados

- `lib/data/repositories/auth_repository.dart` — `deviceToken`, `loginDevice()`.
- `lib/data/services/toy_remote_service.dart` — novo.
- `lib/data/repositories/toy_repository.dart` — reescrito (service HTTP, mutações `Future`, reversão em falha).
- `lib/widgets/auth_gate.dart` — novo (`ensureOperatorSession`).
- `lib/widgets/modal_launchers.dart` — `openBusinessSettingsScreen` usa o gate extraído; `showAddToySheet` ganha o gate.
- `lib/ui/features/catalog/view_models/toy_catalog_cubit.dart` — métodos `async`, repassa erro pra View.
- `lib/ui/features/catalog/views/catalog_view.dart` — `initState`/refresh, `_confirmRemove`/`_MiniField` commit `async` com reversão + `SnackBar`.
- `lib/ui/features/catalog/views/add_toy_sheet_view.dart` — `_submit` `async`, só fecha em sucesso (mesmo padrão de `BusinessSettingsView._save`).
- `lib/state/app_state.dart` — remove `addToy`/`updateToyPrice`/`updateToyBlock`/`removeToy`/`toyHasRentals` (dead code, sem chamador).
- `lib/main.dart` — `loginDevice()` no boot (`Future.wait` junto de `restoreSession()` — ambos só leem config/fazem 1 chamada de rede curta, não travam o boot mais que hoje); injeta `ToyRemoteService`.
- `.gitignore` — `secrets.json`. `secrets.example.json` — novo, documenta as chaves.
- `test/fakes/fake_device_session.dart` — novo (espelha `fake_auth_backend.dart`, mas pro login de dispositivo).
- `test/toy_catalog_cubit_test.dart`, `test/design_v3_test.dart` (ou onde mais tocar catálogo) — atualiza fakes/expectativas (`id` não é mais `custom_*`, é o hex devolvido pelo backend fake).

## Modelo de dados / estado

- `Toy` (domain model) — inalterado. `id` passa a ser o `ObjectId` hex que o backend gera (era `custom_<timestamp>` local) — nenhum código depende do prefixo `custom_` além de um teste, que é atualizado.
- `AuthRepository` ganha `deviceToken` (`String?`, só em memória) ao lado do `token` de operador real já existente.

## Riscos / dependências

- **Catálogo de produção começa vazio** — ninguém nunca chamou `POST /api/toys` em produção de verdade. Mesma decisão já tomada nas specs 022/024 ("não migra dado local existente"): depois do merge, alguém precisa recriar o catálogo via "Novo brinquedo" no app (agora exige login) contra produção. Não é bug desta spec, é consequência da decisão — registrar no rollout, não no código.
- Credencial de dispositivo embutida no app: ver "Decisão — sessão de dispositivo" do `spec.md` pra por que o blast radius é aceitável (só lê catálogo).
- Zero-breakage: `test/toy_catalog_cubit_test.dart` e qualquer teste que comece o app sem fake de `AuthRepository`/`ToyRepository` precisa do mesmo tratamento que a 024 deu (`test/fakes/`).

## Alternativas consideradas

- **Uma sessão só (dispositivo = operador real)** — descartada na aprovação da spec: credencial embutida no app com poder de escrita é risco grande demais; separar mantém o motivo da 022 (auditoria por pessoa) intacto.
- **Debounce na edição inline do grid** — desnecessário: `_MiniField` já só comita no blur, não por tecla.
- **Rodar `addNew`/etc. ainda síncronos, erro só logado (igual hoje com SQLite)** — descartado: SQLite local não falha na prática, HTTP falha (rede, sessão expirada); silenciar isso divergiria o catálogo local do backend sem o operador nunca saber, repetindo o problema que a 024 evitou em `BusinessSettings`.
