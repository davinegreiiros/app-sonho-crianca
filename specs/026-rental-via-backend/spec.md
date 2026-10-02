# Spec: Rental via backend — login fica só com o administrador

Status: Implemented
Criado: 2026-10-01

Terceira fatia da árvore aberta pela [022-backend-sync-fundacao](../022-backend-sync-fundacao/spec.md), depois de [024](../024-sync-backend-fundacao/spec.md) (`BusinessSettings`) e [025](../025-catalogo-sessao-dispositivo/spec.md) (`Toy`). Reaproveita a sessão de dispositivo construída na 025. `Turno.monitorName` continua um rótulo local, não ligado a `Operator` (ver "Decisão" abaixo — a 025 apontava isso como pendente, decidido aqui que **não** devem ser a mesma coisa).

## Problema

`Rental` — a locação em si, o objeto central do negócio — ainda é só local (SQLite, spec 020). Dois aparelhos não compartilham locações nem caixa: o motivo inteiro do backend existir (`022`) ainda não vale pro dado mais importante. O backend já tem a API pronta desde a `001-fundacao-auth-crud` (`GET/POST /api/rentals`, `PATCH /api/rentals/:id/{finish,cancel,extend}`) — nenhuma mudança de backend é necessária nesta spec.

## Colisão de arquitetura (achada ao planejar esta fatia)

O backend exige operador real autenticado (`requireOperator`) em **toda** rota de `rentals`, inclusive leitura — e grava `createdByOperatorId` obrigatoriamente em toda locação criada. O posto ([023-posto-monitor-painel](../023-posto-monitor-painel/spec.md), "Quem é você hoje") hoje abre **sem conta nenhuma** — só um nome livre digitado, guardado em `Turno.monitorName`, e cada ação de locação (criar, estender, cancelar, finalizar) é feita sem nenhum conceito de sessão. Migrar `Rental` pro backend sem mudar isso pararia o posto inteiro: a ação mais frequente do dia a dia (registrar uma locação) passaria a exigir login a cada toque.

## Decisão — login fica só com o administrador (revisada após a 1ª implementação)

> **Revisado pela [027-login-admin-sessao](../027-login-admin-sessao/spec.md)**: a sessão de dispositivo some (leitura também usa a sessão do administrador), a sessão passa pra `SharedPreferences`, "Entrar como administrador" sempre pede login e o admin ganha logout. O resto desta decisão (monitor sem conta, nome livre) continua valendo.

**Esta seção documenta a decisão final** — a primeira versão implementada desta spec trocou "Quem é você hoje" por login real *por turno* (todo monitor logando); revisado antes do merge por confundir duas coisas diferentes: quem tem conta de verdade no backend (auditoria) vs. quem está fisicamente no posto hoje (rótulo local, rotativo). Ver "Correção" mais abaixo pro porquê.

"Quem é você hoje" **continua nome livre, sem conta** — exatamente como na `023`. A sessão de operador real que o backend exige pra escrita de `Rental` é uma camada **separada**, desacoplada do fluxo do posto:

- A guarda de login (`ensureOperatorSession`) entra em ação na **primeira escrita de dinheiro** (criar/estender/cancelar/finalizar locação) — nunca ao abrir o posto. Como a sessão persiste em `flutter_secure_storage` (já existia desde a `024`, sobrevive restart), na prática só **uma pessoa, uma vez por aparelho** — o administrador, ao configurar o aparelho — vê essa tela. Depois disso, nenhum monitor rotativo precisa de conta nem vê login.
- `Turno.monitorName`/`createdByMonitorName`/`finishedByMonitorName` continuam exatamente o que já eram antes desta spec: um rótulo local digitado, nunca verificado, nunca ligado a uma conta. `createdByOperatorId` do backend (auditoria de verdade) aponta pra quem está logado no aparelho (o administrador) — granularidade "aparelho/responsável", não "pessoa física no caixa". Mesma granularidade que já existia de fato (nome digitado nunca foi verificado), só que agora o backend também tem seu próprio registro, nesse nível.
- **Leitura** de locações (`GET /api/rentals`, usada por Home/Relatório/Painel administrativo/lista do posto) reaproveita a **sessão de dispositivo** já construída na `025` — mesma decisão que `Toy` teve: nenhuma tela que só mostra dado passa a exigir login. O backend não distingue "dispositivo" de "operador real" (os dois são só um JWT de operador válido) — a distinção é inteiramente do app.
- Consequência operacional (não é código): só o administrador (quem configura o aparelho) precisa de conta `Operator` cadastrada de verdade. Monitores continuam sem conta, exatamente como sempre foram — rotatividade de equipe não exige recadastro nenhum.

### Correção — por que a primeira versão (login por turno) foi revisada

A versão original fazia login real substituir o nome digitado — todo monitor precisava de conta, e `Turno.monitorName` passava a ser o nome de quem *logou*, não de quem *está no posto*. Problema: numa equipe com monitores rotativos, isso (a) obriga cadastrar/gerenciar senha pra cada pessoa que passa pelo posto, e (b) com a sessão persistindo no aparelho, depois do primeiro login o nome mostrado no turno/painel seria sempre o de quem logou da primeira vez — não o do monitor real daquele turno, perdendo exatamente a informação que a `023` queria capturar. Corrigido voltando o nome a ser livre/local e movendo a guarda de login pra "primeira escrita", não pra "abrir o posto" — só o administrador precisa de conta, o resto volta a ser como era.

### Por que não as alternativas

- **Login a cada locação** (mesma guarda do add-brinquedo, repetida a cada criar/estender/cancelar/finalizar) — rejeitada: alto volume de ações por turno, fricção grande demais pro fluxo principal do negócio. Na prática nem chega a acontecer: a sessão do administrador persiste, então a guarda é um no-op depois da primeira vez.
- **Backend aceitar nome livre sem operador real** — rejeitada: esvazia o motivo original do backend existir (auditoria por pessoa/aparelho, `022`), e exigiria mudar o backend (hoje não precisa de nenhuma mudança).
- **Login real por turno, todo monitor com conta** — era a decisão original desta spec, revertida (ver "Correção" acima).

## Objetivo

`RentalRepository` fala HTTP com o backend em vez de SQLite. Leitura (`load`) usa a sessão de dispositivo, silenciosa. Escrita (`addNew`/`extend`/`cancel`/`finish`) exige sessão de operador real — na prática, só o administrador precisa logar (uma vez por aparelho); o resto do fluxo (nome livre no posto) não muda.

## Achado durante o planejamento — `cancel` não deleta, vira `done` sem pagamento

O backend não tem (nem nunca teve) um terceiro status "cancelado" — `PATCH /api/rentals/:id/cancel` marca a locação como `done`, com `paymentMethod: null`, e a mantém no histórico (`001-fundacao-auth-crud`). Hoje, local, cancelar uma locação ativa a **remove** da lista (`RentalRepository.removeById`) — ela nunca existiu como "done sem pagamento". Sincronizando com o backend, isso muda: uma locação cancelada passa a aparecer em `rentals` como `status: done, paymentMethod: null`, com o `price` que ela já tinha desde a criação (positivo pra tempo fixo).

Isso quebraria silenciosamente qualquer soma de receita/contagem que hoje filtra só por `status == RentalStatus.done` sem checar `paymentMethod` — `ReportCubit`, `AdminPanelCubit`, `HomeCubit` e `MonitorPostoView._turnoGross` fazem exatamente isso. Resolvido como parte desta spec (não é mudança de comportamento de produto, é correção pra manter o comportamento que já existe — cancelamento nunca contou como receita): `Rental` ganha um getter `isCompleted` (`status == done && paymentMethod != null`), usado nesses quatro lugares em vez do `status == done` cru. `PostoSessionCubit.beginClosing` já era seguro (agrupa por `paymentMethod == m`, nunca bate com `null`) — não precisa mudar.

## Fora de escopo

- **Papel/permissão diferenciada por operador** — continua igual à `022`/`025`: qualquer operador logado pode fazer qualquer ação de locação.
- **Migrar `Turno` pro backend** — `Turno` continua 100% local. É controle de turno por aparelho (quem abriu, quando fecha, conferência de caixa), não precisa ser visto por outro aparelho; só `Rental` (o dado que os dois lados de um negócio precisam enxergar) justifica a migração.
- **"Carregar mais" / paginação visível no app** — `load()` percorre todas as páginas do cursor do backend e junta num só `rentals`; não existe UI de paginação nesta fatia (ver `plan.md`, "Riscos", pra quando isso para de ser suficiente).
- **Trocar quem está logado no aparelho** — a sessão de operador real é por aparelho, não por turno/pessoa (ver "Decisão"); revezar monitores nunca passa por login/logout algum, só pelo nome livre de sempre. Trocar o administrador responsável por um aparelho é logout + login manual (fluxo já existente desde a `024`, não precisa de tela nova).
- **Migrar dado local (`rentals` do SQLite) pro backend** — mesma decisão da `022`/`024`/`025`: primeiro boot com o que vier do backend é o que vale.

## Cenários de usuário

1. Dado o posto sem turno aberto, quando o monitor toca num posto livre e digita seu nome, então o turno abre com `Turno.monitorName` = nome digitado — sem conta, sem login, igual sempre foi (spec 023).
2. Dado nenhuma sessão de operador real existe ainda no aparelho, quando um monitor tenta criar/estender/cancelar/finalizar a primeira locação, então é levado ao login (do responsável pelo aparelho) antes — a ação não finge sucesso.
3. Dado a sessão de operador real já existe no aparelho (persistida desde um login anterior, de qualquer momento), quando qualquer monitor cria/estende/cancela/finaliza uma locação, então a ação acontece sem pedir login de novo — a sessão não é por turno nem por pessoa, é por aparelho.
4. Dado uma locação criada ou alterada em um aparelho, quando outro aparelho (outro posto, ou o painel administrativo) atualiza a tela, então vê a mesma locação/estado — a fonte de verdade é o backend, não mais um SQLite por aparelho.
5. Dado a sessão de operador expira (token vencido), quando alguém tenta criar/estender/cancelar/finalizar uma locação, então recebe a mesma UX de sessão expirada da `024` (levado a logar de novo) — a ação não finge sucesso nem se perde silenciosamente.
6. Dado a leitura de locações falha (sem internet), quando Home/Relatório/Painel administrativo/lista do posto tentam carregar, então mostram o que tiver em cache local, sem travar e sem exigir ação do operador — mesma régua da `025` pro catálogo.
7. Dado dois aparelhos tentam reservar a última unidade do mesmo brinquedo ao mesmo tempo, quando ambos tentam criar a locação, então só um consegue (409 do backend, atômico desde a `001`) — o outro recebe uma mensagem clara, não finge sucesso.
8. Dado um turno é fechado no posto (locações criadas e finalizadas durante ele), quando o painel administrativo é aberto, então mostra o turno fechado, o faturamento e as locações daquele turno — mesmas instâncias de `RentalRepository`/`TurnoRepository`, sem cópia nem sincronização extra dentro do app.

## Critérios de aceite

- [x] `RentalRemoteService` novo: `load({token})` (percorre o cursor do backend até `nextCursor == null`, devolve a lista completa), `create`, `extend`, `cancel`, `finish` (todos `{token}`, operador real) via `ApiClient`.
- [x] `RentalRepository` reescrito: `load()` usa `authRepository.deviceToken`; sucesso substitui `rentals`, falha (rede, 401, sem `deviceToken`) não propaga erro, mantém cache (cenário 5). `addNew`/`extend`/`cancel`/`finish` viram `Future`, usam `authRepository.token` (operador real), otimistas com reversão em falha (mesmo padrão de `ToyRepository` da `025`).
- [x] `OpenPostoView`: campo de nome livre **inalterado** (sem conta, sem `ensureOperatorSession`) — `Turno.monitorName` continua vindo do que foi digitado.
- [x] `NewRentalCubit.submit`, `ActiveRentalsCubit.extendActive`/`cancelActive`/`confirmEnd` tornam-se `Future<...>`, repassam a exceção pra View decidir a UI (mesmo padrão de `ToyCatalogCubit` da `025`).
- [x] Views que disparam essas ações (`new_rental_sheet_view.dart`, `active_tab_view.dart`, `end_rental_dialog_view.dart`, `pix_qr_sheet_view.dart`) ganham guarda de login **sempre** (posto ou administrador — a sessão persistida faz dela um no-op depois da primeira vez) e tratamento de erro — `SnackBar` com ação "Entrar" em `ApiUnauthorizedException`, mensagem do servidor nos demais `ApiException`.
- [x] `createdByMonitorName`/`finishedByMonitorName` continuam vindo do rótulo local digitado no posto (`PostoSessionCubit.state.monitorName`, `null` em modo administrador) — **não** de `authRepository.currentOperator` (ver "Correção" acima).
- [x] `RentalLocalService` removido (sem chamador — mesmo destino de `ToyLocalService` na `025`); tabela `rentals` do SQLite fica no schema sem uso, nunca removida (instalação existente não perde dado).
- [x] `Rental.isCompleted` (getter: `status == done && paymentMethod != null`) substitui `status == RentalStatus.done` cru em `ReportCubit`, `AdminPanelCubit`, `HomeCubit` e `MonitorPostoView._turnoGross` (ver "Achado durante o planejamento" acima) — cancelamento nunca conta como receita/atendimento, igual já era (por outro motivo) antes desta spec.
- [x] `main.dart`: `rentalRepository.load()` sai do `Future.wait` que bloqueia o primeiro frame, vai pro background junto da sessão de dispositivo + catálogo.
- [x] Teste cobrindo os 8 cenários acima, sessão de dispositivo/operador mockada — nenhum teste bate no backend real. Inclui um fluxo ponta a ponta: posto cria+finaliza locação, fecha turno, painel administrativo mostra tudo (cenário 8).
- [x] Testes legados que chamam `AppState.submitNew`/`extendActive`/`cancelActive`/`confirmEnd` direto (pré-migração de Cubit) migrados pra passar pelo Cubit real, ou removidos se já redundantes com teste de Cubit existente — mesma régua que a `025` aplicou aos testes de `Toy`.
- [x] `flutter analyze` limpo (0 issues); suíte completa verde (152/152), rodada 2x seguidas sem flake novo.

## Requisitos não-funcionais

- Token de sessão (dispositivo ou operador real) nunca aparece em log/print — mesma régua da constitution.
- Falha de leitura é sempre silenciosa pro usuário (cenário 5) — fluxo principal do dia a dia não pode ficar refém de conectividade.
- Escrita nunca finge sucesso quando falha: reversão otimista sempre que o backend recusar ou a rede cair.

## Dúvidas em aberto

Nenhuma bloqueante — a decisão de arquitetura (login fica só com o administrador, resolvendo a colisão posto-sem-conta vs. backend-exige-operador sem obrigar monitores rotativos a ter conta) foi revisada e confirmada antes do merge (ver "Correção" acima).
