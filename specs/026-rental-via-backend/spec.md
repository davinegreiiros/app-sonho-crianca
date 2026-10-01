# Spec: Rental via backend — login real por turno

Status: Implemented
Criado: 2026-10-01

Terceira fatia da árvore aberta pela [022-backend-sync-fundacao](../022-backend-sync-fundacao/spec.md), depois de [024](../024-sync-backend-fundacao/spec.md) (`BusinessSettings`) e [025](../025-catalogo-sessao-dispositivo/spec.md) (`Toy`). Reaproveita a sessão de dispositivo construída na 025 e resolve a reconciliação `Turno.monitorName`/`Operator` que a 025 deixou explicitamente pendente.

## Problema

`Rental` — a locação em si, o objeto central do negócio — ainda é só local (SQLite, spec 020). Dois aparelhos não compartilham locações nem caixa: o motivo inteiro do backend existir (`022`) ainda não vale pro dado mais importante. O backend já tem a API pronta desde a `001-fundacao-auth-crud` (`GET/POST /api/rentals`, `PATCH /api/rentals/:id/{finish,cancel,extend}`) — nenhuma mudança de backend é necessária nesta spec.

## Colisão de arquitetura (achada ao planejar esta fatia)

O backend exige operador real autenticado (`requireOperator`) em **toda** rota de `rentals`, inclusive leitura — e grava `createdByOperatorId` obrigatoriamente em toda locação criada. O posto ([023-posto-monitor-painel](../023-posto-monitor-painel/spec.md), "Quem é você hoje") hoje abre **sem conta nenhuma** — só um nome livre digitado, guardado em `Turno.monitorName`, e cada ação de locação (criar, estender, cancelar, finalizar) é feita sem nenhum conceito de sessão. Migrar `Rental` pro backend sem mudar isso pararia o posto inteiro: a ação mais frequente do dia a dia (registrar uma locação) passaria a exigir login a cada toque.

## Decisão — login real por turno (resolve a colisão acima)

"Quem é você hoje" deixa de ser um campo de nome livre e passa a ser o **login real de operador** (mesma tela/fluxo da `024`: `LoginView`/`ensureOperatorSession`). O login acontece **uma única vez**, no momento de abrir o posto — a sessão resultante (já persistida em `flutter_secure_storage` desde a `024`, sobrevive a restart) vale o turno inteiro: nenhuma locação individual pede login de novo enquanto o turno estiver aberto.

- `Turno.monitorName` (campo já existente, só exibição/auditoria local) passa a ser preenchido com `Operator.name` do operador que acabou de logar — não mais digitado. Resolve a reconciliação "nome do posto vs. operador de verdade" que a `025` apontou como pendente: a partir desta spec são a mesma coisa.
- **Leitura** de locações (`GET /api/rentals`, usada por Home/Relatório/Painel administrativo/lista do posto) reaproveita a **sessão de dispositivo** já construída na `025` — mesma decisão que `Toy` teve: nenhuma tela que só mostra dado passa a exigir login. O backend não distingue "dispositivo" de "operador real" (os dois são só um JWT de operador válido) — a distinção é inteiramente do app, e a sessão de dispositivo (`AuthRepository.deviceToken`) já é um JWT de operador válido, só com um usuário dedicado.
- **Escrita** (criar/estender/cancelar/finalizar) exige sessão de operador real. No fluxo do posto, ela já existe desde a abertura do turno (nunca pede de novo). No modo administrador (que não passa pelo posto), a mesma guarda `ensureOperatorSession` já usada por Configurações/Catálogo (`025`) entra em ação na primeira ação sensível — consistente com o resto do app.
- Consequência operacional (não é código): cada monitor passa a precisar de uma conta `Operator` cadastrada de verdade (usuário/senha), não mais só um nome digitado na hora. Registrar no rollout, não é um critério de aceite técnico.

### Por que não as alternativas

- **Login a cada locação** (mesma guarda do add-brinquedo, repetida a cada criar/estender/cancelar/finalizar) — rejeitada: alto volume de ações por turno, fricção grande demais pro fluxo principal do negócio.
- **Backend aceitar nome livre sem operador real** — rejeitada: esvazia o motivo original do backend existir (auditoria por pessoa, `022`), e exigiria mudar o backend (hoje não precisa de nenhuma mudança).

## Objetivo

`RentalRepository` fala HTTP com o backend em vez de SQLite. Leitura (`load`) usa a sessão de dispositivo, silenciosa. Escrita (`addNew`/`extend`/`cancel`/`finish`) exige sessão de operador real, obtida uma vez ao abrir o posto (ou sob demanda em modo administrador).

## Achado durante o planejamento — `cancel` não deleta, vira `done` sem pagamento

O backend não tem (nem nunca teve) um terceiro status "cancelado" — `PATCH /api/rentals/:id/cancel` marca a locação como `done`, com `paymentMethod: null`, e a mantém no histórico (`001-fundacao-auth-crud`). Hoje, local, cancelar uma locação ativa a **remove** da lista (`RentalRepository.removeById`) — ela nunca existiu como "done sem pagamento". Sincronizando com o backend, isso muda: uma locação cancelada passa a aparecer em `rentals` como `status: done, paymentMethod: null`, com o `price` que ela já tinha desde a criação (positivo pra tempo fixo).

Isso quebraria silenciosamente qualquer soma de receita/contagem que hoje filtra só por `status == RentalStatus.done` sem checar `paymentMethod` — `ReportCubit`, `AdminPanelCubit`, `HomeCubit` e `MonitorPostoView._turnoGross` fazem exatamente isso. Resolvido como parte desta spec (não é mudança de comportamento de produto, é correção pra manter o comportamento que já existe — cancelamento nunca contou como receita): `Rental` ganha um getter `isCompleted` (`status == done && paymentMethod != null`), usado nesses quatro lugares em vez do `status == done` cru. `PostoSessionCubit.beginClosing` já era seguro (agrupa por `paymentMethod == m`, nunca bate com `null`) — não precisa mudar.

## Fora de escopo

- **Papel/permissão diferenciada por operador** — continua igual à `022`/`025`: qualquer operador logado pode fazer qualquer ação de locação.
- **Migrar `Turno` pro backend** — `Turno` continua 100% local. É controle de turno por aparelho (quem abriu, quando fecha, conferência de caixa), não precisa ser visto por outro aparelho; só `Rental` (o dado que os dois lados de um negócio precisam enxergar) justifica a migração.
- **"Carregar mais" / paginação visível no app** — `load()` percorre todas as páginas do cursor do backend e junta num só `rentals`; não existe UI de paginação nesta fatia (ver `plan.md`, "Riscos", pra quando isso para de ser suficiente).
- **Trocar de operador no meio de um turno aberto sem logout** — um aparelho tem uma sessão de operador real por vez; revezar monitores no mesmo aparelho é fechar turno + logout + outro login (fluxo já existente, não precisa de tela nova).
- **Migrar dado local (`rentals` do SQLite) pro backend** — mesma decisão da `022`/`024`/`025`: primeiro boot com o que vier do backend é o que vale.

## Cenários de usuário

1. Dado o posto sem turno aberto, quando o monitor toca num posto livre, então é levado ao login real de operador (não mais um campo de nome livre) — login bem-sucedido abre o turno com `Turno.monitorName` = nome do operador logado.
2. Dado um turno já aberto (login já feito), quando o monitor cria, estende, cancela ou finaliza uma locação, então a ação acontece sem pedir login de novo.
3. Dado uma locação criada ou alterada em um aparelho, quando outro aparelho (outro posto, ou o painel administrativo) atualiza a tela, então vê a mesma locação/estado — a fonte de verdade é o backend, não mais um SQLite por aparelho.
4. Dado a sessão de operador expira no meio do turno (token vencido), quando o monitor tenta criar/estender/cancelar/finalizar uma locação, então recebe a mesma UX de sessão expirada da `024` (levado a logar de novo) — a ação não finge sucesso nem se perde silenciosamente.
5. Dado a leitura de locações falha (sem internet), quando Home/Relatório/Painel administrativo/lista do posto tentam carregar, então mostram o que tiver em cache local, sem travar e sem exigir ação do operador — mesma régua da `025` pro catálogo.
6. Dado dois aparelhos tentam reservar a última unidade do mesmo brinquedo ao mesmo tempo, quando ambos tentam criar a locação, então só um consegue (409 do backend, atômico desde a `001`) — o outro recebe uma mensagem clara, não finge sucesso.
7. Dado o modo administrador (sem ter passado pelo posto), quando o administrador tenta criar/estender/cancelar/finalizar uma locação sem sessão de operador real, então é levado ao login primeiro — mesma guarda que Configurações/Catálogo já usam.

## Critérios de aceite

- [x] `RentalRemoteService` novo: `load({token})` (percorre o cursor do backend até `nextCursor == null`, devolve a lista completa), `create`, `extend`, `cancel`, `finish` (todos `{token}`, operador real) via `ApiClient`.
- [x] `RentalRepository` reescrito: `load()` usa `authRepository.deviceToken`; sucesso substitui `rentals`, falha (rede, 401, sem `deviceToken`) não propaga erro, mantém cache (cenário 5). `addNew`/`extend`/`cancel`/`finish` viram `Future`, usam `authRepository.token` (operador real), otimistas com reversão em falha (mesmo padrão de `ToyRepository` da `025`).
- [x] `OpenPostoView`: campo de nome livre substituído por `ensureOperatorSession` — sucesso abre o turno com `monitorName: authRepository.currentOperator!.name`.
- [x] `NewRentalCubit.submit`, `ActiveRentalsCubit.extendActive`/`cancelActive`/`confirmEnd` tornam-se `Future<...>`, repassam a exceção pra View decidir a UI (mesmo padrão de `ToyCatalogCubit` da `025`).
- [x] Views que disparam essas ações (`new_rental_sheet_view.dart`, `active_tab_view.dart`, `end_rental_dialog_view.dart`, `pix_qr_sheet_view.dart`) ganham guarda de login onde a sessão não é garantida (modo administrador) e tratamento de erro — `SnackBar` com ação "Entrar" em `ApiUnauthorizedException`, mensagem do servidor nos demais `ApiException`.
- [x] `createdByMonitorName`/`finishedByMonitorName` passam a vir sempre de `authRepository.currentOperator?.name` (hoje só vinha preenchido no fluxo do posto; a partir daqui, qualquer escrita já tem sessão real garantida pela guarda, então sempre tem nome).
- [x] `RentalLocalService` removido (sem chamador — mesmo destino de `ToyLocalService` na `025`); tabela `rentals` do SQLite fica no schema sem uso, nunca removida (instalação existente não perde dado).
- [x] `Rental.isCompleted` (getter: `status == done && paymentMethod != null`) substitui `status == RentalStatus.done` cru em `ReportCubit`, `AdminPanelCubit`, `HomeCubit` e `MonitorPostoView._turnoGross` (ver "Achado durante o planejamento" acima) — cancelamento nunca conta como receita/atendimento, igual já era (por outro motivo) antes desta spec.
- [x] `main.dart`: `rentalRepository.load()` sai do `Future.wait` que bloqueia o primeiro frame, vai pro background junto da sessão de dispositivo + catálogo.
- [x] Teste cobrindo os 7 cenários acima, sessão de dispositivo/operador mockada — nenhum teste bate no backend real.
- [x] Testes legados que chamam `AppState.submitNew`/`extendActive`/`cancelActive`/`confirmEnd` direto (pré-migração de Cubit) migrados pra passar pelo Cubit real, ou removidos se já redundantes com teste de Cubit existente — mesma régua que a `025` aplicou aos testes de `Toy`.
- [x] `flutter analyze` limpo (0 issues); suíte completa verde (150/150), rodada 2x seguidas sem flake novo.

## Requisitos não-funcionais

- Token de sessão (dispositivo ou operador real) nunca aparece em log/print — mesma régua da constitution.
- Falha de leitura é sempre silenciosa pro usuário (cenário 5) — fluxo principal do dia a dia não pode ficar refém de conectividade.
- Escrita nunca finge sucesso quando falha: reversão otimista sempre que o backend recusar ou a rede cair.

## Dúvidas em aberto

Nenhuma bloqueante — a decisão de arquitetura (login real por turno, resolvendo a colisão posto-sem-conta vs. backend-exige-operador) já foi discutida e aprovada antes deste rascunho. Detalhe de UX a confirmar no `plan.md`, não aqui: cópia exata da tela de login quando aberta a partir do posto (reaproveitar `LoginView` tal como está vs. pequeno ajuste de texto) — decisão de UI, não de produto.
