# Plan: Rental via backend — login real por turno

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Mesmo strangler-fig da `024`/`025`: troca o `Service` por baixo de `RentalRepository`, interface pública minimamente alterada (escrita vira `Future`, leitura continua síncrona via `rentals`, que continua a mesma lista mutável — vários Cubits dependem disso). A parte nova de produto é mover "Quem é você hoje" de nome livre pra login real — tecnicamente é só trocar a origem de uma `String` (de um `TextEditingController` pra `AuthRepository.currentOperator!.name`), o resto do fluxo de `Turno`/`PostoSessionCubit` não muda de forma.

1. **`RentalRemoteService`** (novo, espelha `ToyRemoteService`):
   - `load({required String token}) → Future<List<Rental>>` — chama `GET /api/rentals?limit=200&cursor=...` em loop até `nextCursor == null`, concatena `items`, devolve a lista completa. `limit=200` (teto do backend) minimiza chamadas; ver "Riscos" pra quando isso parar de bastar.
   - `create(..., {required String token}) → Future<Rental>` — `POST /api/rentals`.
   - `extend(id, durationMin, {required String token}) → Future<Rental>` — `PATCH /api/rentals/:id/extend`.
   - `cancel(id, {required String token}) → Future<Rental>` — `PATCH /api/rentals/:id/cancel`.
   - `finish(id, paymentMethod, {required String token}) → Future<Rental>` — `PATCH /api/rentals/:id/finish`.
   - Mapeamento JSON↔`Rental`: campos batem 1:1 com o domain model exceto `createdByMonitorName`/`finishedByMonitorName`, que não existem no backend (lá são `createdByOperatorId`/`finishedByOperatorId`, auditoria por id) — o Service ignora esses dois campos do backend ao desserializar uma locação vinda de `load()` (fica `null`; o app não tem endpoint pra resolver id→nome de operador, e não precisa: só interessa saber "quem" no momento da própria ação, não ao listar as dos outros). Em `create`/`finish`, quem chama (`RentalRepository`) preenche esses dois campos **localmente**, com `authRepository.currentOperator!.name`, no objeto que populará `rentals` — não vêm do backend.

2. **`RentalRepository` reescrito** (mesmo formato de `ToyRepository` pós-`025`):
   - Construtor: `{required RentalRemoteService service, required AuthRepository authRepository}` — larga `RentalLocalService`.
   - `load()` — usa `authRepository.deviceToken`. Sucesso substitui `rentals` (clear+addAll, mesma técnica de hoje, preserva identidade da lista pros Cubits que guardam referência). Falha (sem `deviceToken`, rede, 401) não propaga nada — mantém o que já estava (cenário 5), só loga via `debugPrint`. Sem retry automático aqui (diferente do catálogo): `main.dart` já encadeia `loginDevice()` antes de chamar `toyRepository.load()`/`rentalRepository.load()`, então um 401 nesse ponto já é "sessão de dispositivo realmente indisponível agora", não vale a pena tentar de novo só pra `Rental`.
   - `addNew(...)` — `authRepository.token` (nulo → lança `ApiUnauthorizedException` direto, sem chamar o backend à toa). Otimista: cria o `Rental` local com um id temporário, adiciona a `rentals`, notifica; chama `service.create(...)`; sucesso substitui o id temporário pelo id real do backend (mesmo objeto, mesma posição) e notifica de novo; falha remove o item otimista, notifica, relança a exceção. `createdByMonitorName` do objeto local = `authRepository.currentOperator!.name` (preenchido na hora, não espera resposta do backend).
   - `extend(id, durationMin)` — **atenção**: a assinatura pública continua recebendo `durationMin` **absoluto** (novo total — mesmo contrato que os chamadores, `ActiveRentalsCubit.extendActive`, já usam), mas a rota do backend (`PATCH /api/rentals/:id/extend`) espera um **incremento** no campo `durationMin` do corpo (a função da repository do backend é `extend(id, addMinutes)` — a rota só repassa o nome do campo, não o significado). `RentalRepository.extend` calcula `addMinutes = durationMin - (atual.durationMin ?? 0)` antes de chamar `_service.extend(id, addMinutes, ...)` — passar o total absoluto direto pro backend duplicaria o incremento a cada chamada. Otimista: aplica o novo total localmente, notifica, chama o service com o delta; falha reverte os campos antigos e relança.
   - `cancel(id)` (substitui `removeById`, mas chamado só onde hoje é cancelamento de ativa, ver item 6) — otimista: remove localmente, notifica, chama `service.cancel`; falha reinsere o item removido (mesma posição, via índice salvo antes de remover) e relança.
   - `finish(id, paymentMethod, {finalPrice})` — otimista: aplica `status=done`/`endedAt`/`paymentMethod`/`finishedByMonitorName` localmente, notifica, chama `service.finish`; falha desfaz (volta pra `active`, limpa os campos) e relança.
   - Sem sessão real (`authRepository.token == null`) em qualquer um dos quatro acima: lança `ApiUnauthorizedException` **antes** de tocar em `rentals` — nunca aplica otimista pra depois reverter uma ação que nem chegou a tentar o backend.

3. **Login real no posto** (`OpenPostoView` + `PostoSessionCubit`):
   - `PostoSessionCubit.openOrResume` **não muda de assinatura** — continua recebendo `monitorName` como `String`. Só a `View` muda a origem do valor.
   - `_OpenPostoViewState._confirmEnter`/UI do nome livre são removidos. `_tapPosto` num posto livre chama `ensureOperatorSession(context)` direto; sucesso chama `openOrResume(toyId, monitorName: context.read<AuthRepository>().currentOperator!.name)`. Cancelar o login não abre o posto (mesmo contrato de `ensureOperatorSession`: `false` = não prossegue).
   - Posto já ocupado (retomar) continua sem pedir nada — mesmo comportamento de hoje (`existing != null` não pede nome nem login; a sessão de quem abriu originalmente já está ativa no aparelho).
   - `TestKeys.postoNameField`/`postoEnterButton` somem (campo deixou de existir); testes que os usam são atualizados pra simular login via `AuthRepository` fake, não mais `enterText`.

4. **Cubits de escrita viram `Future`** (mesmo tratamento que `ToyCatalogCubit` recebeu na `025`):
   - `NewRentalCubit.submit({createdByMonitorName})` → `Future<Rental>`, delega a `_rentalRepository.addNew(...)`, deixa a exceção subir.
   - `ActiveRentalsCubit.extendActive`/`cancelActive`/`confirmEnd` → `Future<void>`, mesma ideia.
   - `AppState.submitNew`/`extendActive`/`cancelActive`/`confirmEnd` — **removidos** (não "convertidos pra `Future` sem `await`"): já não têm chamador em produção (só testes legados pré-migração de Cubit, ver item 7). Mesma régua da `025` pro Toy.

5. **Views ganham guarda + tratamento de erro**:
   - `new_rental_sheet_view.dart` — botão "Iniciar locação" vira `onPressed` assíncrono: se `fromPosto` é falso (modo administrador), chama `ensureOperatorSession(context)` primeiro; aborta se `false`. Depois `await cubit.submit(createdByMonitorName: context.read<AuthRepository>().currentOperator?.name)` dentro de `try/catch`, fecha a sheet só em sucesso; em erro mostra `SnackBar` (ação "Entrar" em `ApiUnauthorizedException`, mensagem do servidor em `ApiException`, texto genérico em `ApiNetworkException`) sem fechar a sheet — operador não perde o que digitou.
   - `active_tab_view.dart` (`extendActive`/`cancelActive` — modo administrador, grade de ativas) — mesma guarda antes, mesmo tratamento depois (helper comum, ver item 6).
   - `end_rental_dialog_view.dart`/`pix_qr_sheet_view.dart` (`confirmEnd`) — mesma guarda/tratamento; `createdByMonitorName`/`actingMonitorName` deixa de vir só de `PostoSessionCubit.state.monitorName` (que seria `null` em modo administrador) e passa a cair em `context.read<AuthRepository>().currentOperator?.name` como fallback — sempre tem valor depois da guarda passar.
   - Helper `showRentalActionError(BuildContext, Object error)` novo em `lib/widgets/` (mesmo papel do `_showToyActionError` que `catalog_view.dart` já tem, só que compartilhado entre as 4 Views acima em vez de duplicado) — reduz repetição do `SnackBar` com ação "Entrar".
   - Dentro do fluxo do posto (`fromPosto == true` / `MonitorPostoView`), a guarda `ensureOperatorSession` sempre retorna `true` sem pedir nada (sessão já aberta ao entrar no posto) — o `await` existe só por uniformidade de código, não gera UI extra no caminho feliz.

6. **`cancelActive`** — já mapeia 1:1 pra `PATCH /:id/cancel` (locação ativa encerrada sem pagamento); `RentalRepository.cancel` (item 2) substitui `removeById`. `AppState.cancelActive`/linha 365 cai junto com o resto do item 4.

7. **Testes legados pré-Cubit** (`extend_rental_test.dart`, `open_ended_rental_test.dart`, `rental_notifications_test.dart`, `extend_time_widget_test.dart`, `full_app_journey_test.dart`, `catalog_tickets_test.dart`, `design_v3_test.dart` — os que chamam `state.submitNew()`/`extendActive`/`cancelActive`/`confirmEnd` direto em `AppState`) — convertidos pra chamar os Cubits reais (`NewRentalCubit`/`ActiveRentalsCubit`) com `await`, igual a UI já faz. Onde o teste já tem cobertura equivalente via Cubit em outro arquivo, remover a duplicata em vez de portar.

8. **`main.dart`** — `rentalRepository.load()` sai do `Future.wait` de boot (que hoje tem `restoreSession()`/`rentalRepository.load()`/`turnoRepository.load()`); entra no mesmo `unawaited(...)` que já dispara `loginDevice()` → `toyRepository.load()`, encadeado: `loginDevice()` → `Future.wait([toyRepository.load(), rentalRepository.load()])` (os dois dependem só do `deviceToken`, podem rodar em paralelo). `turnoRepository.load()` continua no `Future.wait` bloqueante (é só leitura de SQLite local, rápido, sem rede).

## Arquivos afetados

- `lib/data/services/rental_remote_service.dart` — novo.
- `lib/data/repositories/rental_repository.dart` — reescrito (service HTTP, mutações `Future`, otimista+reversão, `cancel` substitui `removeById`).
- `lib/widgets/modal_launchers.dart` — nenhuma mudança de assinatura esperada (`showNewRentalSheet`/`showEndRentalDialog` já só abrem a UI; a guarda entra dentro das Views, não aqui — diferente de `showAddToySheet`, que guardava antes de abrir a sheet inteira, porque aqui o formulário em si (escolher brinquedo, nome, duração) não precisa de sessão real, só o `submit` final precisa).
- `lib/ui/features/posto/views/open_posto_view.dart` — remove nome livre, usa `ensureOperatorSession` + `AuthRepository.currentOperator`.
- `lib/ui/features/rental/view_models/new_rental_cubit.dart` — `submit` vira `Future`.
- `lib/ui/features/rental/view_models/active_rentals_cubit.dart` — `extendActive`/`cancelActive`/`confirmEnd` viram `Future`.
- `lib/ui/features/rental/views/new_rental_sheet_view.dart` — `onPressed` assíncrono, guarda em modo administrador, tratamento de erro.
- `lib/ui/features/rental/views/active_tab_view.dart` — idem pra `extendActive`/`cancelActive`.
- `lib/ui/features/rental/views/end_rental_dialog_view.dart`, `lib/ui/features/rental/views/pix_qr_sheet_view.dart` — idem pra `confirmEnd`.
- `lib/widgets/rental_action_error.dart` — novo helper `showRentalActionError`.
- `lib/state/app_state.dart` — remove `submitNew`/`extendActive`/`cancelActive`/`confirmEnd` (dead code em produção).
- `lib/main.dart` — `rentalRepository.load()` sai do boot bloqueante, injeta `RentalRemoteService`.
- `lib/data/services/rental_local_service.dart` — **removido** (mesmo destino de `ToyLocalService` na `025` — não "unused mas mantido", de fato deletado); `test/data/rental_local_service_test.dart` (testava só essa classe) e `test/data/persistence_round_trip_test.dart` (seu único teste restante era exatamente "locação sobrevive a restart via SQLite") removidos junto. Tabela `rentals` em `app_database.dart` fica no schema sem uso, nunca removida.
- `test/fakes/fake_rental_backend.dart` — novo (espelha `fake_toy_backend.dart`).
- `test/rental_repository_test.dart` — novo, cobre os 7 cenários.
- `test/extend_rental_test.dart`, `test/open_ended_rental_test.dart`, `test/rental_notifications_test.dart`, `test/extend_time_widget_test.dart`, `test/full_app_journey_test.dart`, `test/catalog_tickets_test.dart`, `test/design_v3_test.dart` — migrados pra Cubit real (item 7 acima) ou com fakes de `RentalRepository`/`AuthRepository` injetados.
- Qualquer teste que monta `SonhoDeCriancaApp(...)` sem fakes e visita uma tela que lê/escreve `Rental` (Home, Relatório, Painel, Posto, Catálogo) precisa do mesmo tratamento que a `025` deu pro catálogo — senão cai no backend real.

## Modelo de dados / estado

- `Rental` (domain model) — inalterado. `id` passa a ser o `ObjectId` hex do backend (era `r<timestamp>` local) — nenhum código depende do prefixo além de testes, que são atualizados.
- `createdByMonitorName`/`finishedByMonitorName` — continuam `String?` locais, mas agora **sempre** vêm de `AuthRepository.currentOperator?.name` no momento da ação (nunca mais digitados nem `null` por "modo administrador"), já que toda escrita passa a exigir sessão real primeiro.
- `Turno.monitorName` — mesmo campo, mesma forma; só a origem do valor (de `TextEditingController` pra `Operator.name`) muda, em `OpenPostoView`.

## Riscos / dependências

- **Histórico de locações sem paginação visível** — `load()` busca tudo de uma vez (em páginas de 200, mas sem parar). Aceitável no tamanho atual do negócio; se o histórico crescer muito, isso vira lento/pesado no boot — não é bug desta spec, é um teto conhecido (mesmo espírito da ressalva 3 do security-review da `001`, que criou a paginação no backend justamente pensando nisso). Próxima spec de `Rental`, se for o caso, resolve com paginação de verdade na UI (ex. Relatório carregando por período, Home só pedindo "hoje").
- **Cada monitor precisa de conta `Operator` real** — mudança operacional: antes bastava digitar um nome, agora precisa de usuário/senha cadastrados (`scripts/seed-operator.ts` no backend). Registrar no rollout: criar uma conta por monitor antes do primeiro turno pós-merge.
- **Produção sem dado nenhum de `Rental` ainda** (consequência de nunca ter chamado `POST /api/rentals` de verdade) — mesma decisão já tomada nas specs `022`/`024`/`025`: não migra SQLite local pro backend; o histórico local de cada aparelho fica pra trás.
- **Zero-breakage**: todo teste que hoje monta o app sem fakes de `RentalRepository`/`AuthRepository` e visita uma tela com `Rental` precisa do mesmo tratamento que a `025` deu — risco de teste silenciosamente batendo em produção se esquecido (mesmo jeito que `modal_launchers_test.dart` pegou na `025`).

## Alternativas consideradas

- **Login a cada locação (não por turno)** — descartada na aprovação da spec: fricção demais pro volume de ações do dia a dia.
- **Sessão de dispositivo também pra escrita de `Rental`** (criar/estender/cancelar sem conta, só `finish` exigindo real — ideia originalmente anotada como nota de rodapé na `025`) — descartada na aprovação desta spec em favor de login real pra **toda** escrita: mantém auditoria completa (quem criou, não só quem finalizou) e não há mais a complexidade de decidir "essa ação é sensível o bastante pra pedir login, aquela não" — ou é leitura (sempre sessão de dispositivo) ou é escrita (sempre sessão real), sem meio-termo por tipo de ação.
- **Buscar nome do operador por id no backend** (pra preencher `createdByMonitorName` de locações criadas por outro aparelho, ao invés de deixar `null` nesse caso) — descartada: exigiria um endpoint novo (`GET /api/operators/:id`) só pra isso; o campo já era só exibição local (nunca foi sincronizado entre aparelhos, nem na v1 do posto), então o comportamento não piora, só deixa de fingir que sabe um dado que nunca soube.
