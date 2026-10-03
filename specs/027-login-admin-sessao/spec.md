# Spec: Login do administrador na entrada + sessão única + logout

Status: Implemented
Criado: 2026-10-02
Aprovado: 2026-10-02 (pedido direto do dono do produto)

Revisa a parte de sessão das specs [024](../024-sync-backend-fundacao/spec.md), [025](../025-catalogo-sessao-dispositivo/spec.md) e [026](../026-rental-via-backend/spec.md), alinhando o app com o backend: [backend#002](../../../sonho-de-crianca-backend/specs/002-multi-tenant-aparelho-registrado/spec.md) (abandonada — "o login é único, do administrador dono do aluguel; não há motivo para credencial separada por aparelho") e [backend#003](../../../sonho-de-crianca-backend/specs/003-turno-posto-trilha/spec.md) ("o app pede login ao entrar no modo administrador, o que já gera token novo" — fechamento de turno exige JWT com no máximo 15 min).

## Problema

1. **"Entrar como administrador" não pede login na prática.** A guarda (`ensureOperatorSession`) só abre o login quando não há sessão salva. A sessão é restaurada no boot sem checar validade: um JWT já expirado (12h, sem refresh — backend#001) conta como "logado". Resultado: o botão entra direto no painel, e o login só aparece quando a primeira locação volta 401 — exatamente o que o dono do produto relatou ("está pedindo somente quando vou fazer a locação").
2. **Não existe logout nem saída do modo administrador.** Uma vez em `PostoMode.admin`, só reinstalando/limpando dado do app.
3. **Credencial de dispositivo no build (`secrets.json`).** A 025 criou uma segunda sessão ("dispositivo", `DEVICE_OPERATOR_USERNAME/PASSWORD` via `--dart-define-from-file`) só pra leitura. O backend nunca teve esse conceito (é só outro operador comum) e decidiu explicitamente que não há credencial por aparelho (backend#002). É senha de operador embutida no binário.
4. **Erro ao tocar "Entrar" na SnackBar** de sessão ausente: o callback usa o `BuildContext` do sheet/diálogo de onde o erro saiu, que pode já ter sido desmontado quando a SnackBar é tocada (stack termina em `_InkResponseState.handleTap`).

## Decisão

- **Uma sessão só: a do administrador.** Some a sessão de dispositivo (`loginDevice`, `deviceToken`, `secrets.json`). Leitura e escrita usam o mesmo token do administrador.
- **"Entrar como administrador" pede login quando não há sessão válida** (aparelho novo, "Sair da conta", token vencido ou derrubado por 401). Com sessão válida entra direto: voltar pros postos e entrar de novo não obriga relogar (revisado pelo dono do produto em 2026-10-02; a 1ª versão pedia sempre e virou atrito). Consequência aceita: enquanto a sessão vale (até 12h), quem estiver com o tablet entra no administrativo; "Sair da conta" é o jeito de travar. O "login recente" (até 15 min) do fechamento de turno (backend#003) fica pra spec que consumir `/api/shifts` — o 403 daquela rota pede login.
- **Sessão persiste em `SharedPreferences`** (decisão do dono do produto, substitui `flutter_secure_storage`): o posto continua usando a sessão do administrador pra registrar locação sem ninguém relogar, como na 026. Sessão expirada é descartada sozinha (lida do `exp` do JWT), e qualquer 401 do backend também derruba a sessão — aí o app pede login de novo na próxima ação que precisar.
- **Menu do administrador no cabeçalho** com duas saídas: "Voltar para os postos" (mantém a sessão — o posto segue funcionando) e "Sair da conta" (logout: apaga a sessão e volta pra escolha de posto).

### Trade-off aceito — `SharedPreferences` em vez de armazenamento seguro

`SharedPreferences` é texto puro no sandbox do app (Android: XML em `/data/data/<app>/shared_prefs`; iOS: plist). Não é criptografado em repouso, ao contrário de Keystore/Keychain. Aceito porque: o token expira em 12h e não tem refresh; o único dado guardado é `{token, operator: {id, name, username}}` (nunca senha); o aparelho é um tablet do próprio negócio. Mitigação: `android:allowBackup="false"` pra o token não ir pro backup em nuvem do Google e reaparecer em outro aparelho. Sessão salva pelo `flutter_secure_storage` em versões anteriores não é migrada — o administrador loga uma vez depois da atualização.

### Consequência operacional

Aparelho recém-instalado (ou depois de "Sair da conta") não tem sessão nenhuma: o posto mostra o catálogo/histórico em cache/seed e pede o login do administrador na primeira locação, como a 026 já fazia. O administrador configura o aparelho entrando uma vez; depois disso, "Voltar para os postos" deixa o tablet pronto pros monitores por até 12h.

## Fora de escopo

- Consumir `/api/shifts`, `/api/notifications`, `/api/dashboard`, trilha e cortesia (backend#003) — spec própria.
- Refresh token / renovação silenciosa — backend não tem (backend#001).
- Conta de monitor — continua nome livre (026).
- Mudança no backend: nenhuma. Só a frase do contrato do backend#003 que citava "sessão de dispositivo" é atualizada.

## Cenários de usuário

1. Dado o app na escolha de posto sem sessão válida, quando toco "Entrar como administrador", então a tela de login abre; só entro no modo administrador depois de logar. Com sessão válida, entro direto.
2. Dado a tela de login aberta pelo botão de administrador, quando toco "Voltar", então continuo na escolha de posto, sem entrar no admin.
3. Dado sessão salva com JWT expirado, quando o app abre, então ela é descartada (o app não se considera logado).
4. Dado modo administrador, quando abro o menu do cabeçalho e escolho "Sair da conta" e confirmo, então a sessão é apagada (inclusive do armazenamento) e volto pra escolha de posto.
5. Dado modo administrador, quando escolho "Voltar para os postos", então volto pra escolha de posto e a sessão continua — um monitor registra locação sem login.
6. Dado sessão válida, quando o app abre ou o administrador acaba de logar, então catálogo e locações são buscados no backend com o token do administrador.
7. Dado nenhuma sessão, quando o app abre, então catálogo/locações ficam no cache/seed, sem erro e sem chamada com token vazio.
8. Dado uma leitura ou escrita que volta 401, então a sessão é derrubada e a próxima ação que precisar dela pede login.
9. Dado um erro de sessão numa locação com a SnackBar "Entrar", quando toco "Entrar" depois que o sheet de origem fechou, então a tela de login abre sem exceção.

## Critérios de aceite

- [x] `AuthRepository` persiste em `SharedPreferences` via `AuthSessionLocalService`; `flutter_secure_storage` removido do `pubspec.yaml`.
- [x] `isLoggedIn` falso para JWT com `exp` no passado; `restoreSession` descarta sessão expirada.
- [x] Sem `loginDevice`/`deviceToken`; `ToyRepository.load`/`RentalRepository.load` usam `token` do administrador, pulam sem token e fazem logout em 401.
- [x] `main.dart` busca catálogo/locações no boot (se houver sessão) e de novo a cada login.
- [x] Botão "Entrar como administrador" abre o login só sem sessão válida; voltar pros postos e entrar de novo não pede login.
- [x] Menu no cabeçalho do admin: "Voltar para os postos" e "Sair da conta" (com confirmação).
- [x] "Entrar" da SnackBar não usa `BuildContext` desmontado.
- [x] `secrets.example.json` removido; `launch.json` sem `--dart-define-from-file`; `android:allowBackup="false"`.
- [x] Backend#003: frase de "sessão de dispositivo" atualizada.
- [x] Testes cobrindo cenários 1–9; `flutter analyze` limpo; suíte completa verde.

## Requisitos não-funcionais

- Token nunca em log/print (constitution).
- Falha de leitura continua silenciosa (cenário 7, mesma régua da 025/026).

## Dúvidas em aberto

Nenhuma.
