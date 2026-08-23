# Spec: Migração de arquitetura para camadas (MVVM + data/domain/ui)

Status: Implemented
Criado: 2026-08-22

Esta é a spec "guarda-chuva": define a arquitetura-alvo, as convenções e o roadmap de fatias. Ela mesma só cobre a fundação (estrutura de pastas + dependências + migração dos modelos de domínio, sem tocar em Cubit/View). Cada feature migra numa spec própria depois, seguindo o roadmap abaixo.

## Problema

Hoje o app inteiro depende de um único `AppState` (`lib/state/app_state.dart`) como fonte de verdade — ele mistura estado de UI, regra de negócio (cálculo de locação, disponibilidade de brinquedo, PIX, notificações) e, potencialmente, acesso a dado, tudo num só `ChangeNotifier`. Isso era documentado e intencional na `constitution.md` até esta spec.

À medida que o app cresce (mais specs implementadas: catálogo, PIX, notificações, tempo corrido), esse `AppState` único tende a virar um gargalo: fica difícil testar regra de negócio isolada de UI, difícil saber quem consome o quê, e qualquer widget pode ler/escrever qualquer parte do estado global.

Para quem: o dono do produto/mantenedor (você), que vai continuar adicionando features e precisa que o código continue fácil de testar e estender.

## Objetivo

O código passa a seguir a separação em camadas `data/` (services + repositories), `domain/` (models + use cases opcionais) e `ui/` (view_models + views por feature), com `ViewModel`s por tela — implementados como `Cubit` (`flutter_bloc`) — substituindo o acesso direto e amplo ao `AppState` global. A migração acontece fatiada por feature, cada fatia em sua própria spec, sem quebrar nenhum comportamento existente do app em nenhum momento.

## Decisões

- **State management da camada ViewModel: Cubit (`flutter_bloc`).** Estado imutável e nomeado por tela/feature (ex.: `RentalTimerRunning`/`RentalTimerExpired`) sem o boilerplate de eventos do Bloc "evento puro", que não se justifica pro tamanho atual do app. Cada `ViewModel` é um `Cubit<TelaState>`. `provider` continua para DI de Services/Repositories; `Cubit`s são expostos via `BlocProvider`/`MultiBlocProvider`. Ver comparação completa abaixo.
- **Igualdade de estado do Cubit: `equatable`, não `freezed`/`built_value`.** Evita dependência de codegen/`build_runner` sem necessidade comprovada. Modelos de domínio (`lib/domain/models/`) continuam classes imutáveis escritas à mão, como já eram em `lib/models/`.
- **Um `Repository` por domínio**: `ToyRepository`, `RentalRepository`, `BusinessSettingsRepository` — em vez de uma fachada única. Motivo: os três domínios já são bem separados hoje (`Toy`, `Rental`, `BusinessSettings` são modelos independentes no `AppState`), então repository por domínio dá granularidade real de teste/mock sem custo extra, e evita recriar um segundo "God object" no lugar do `AppState`.
- **Use Cases só quando justificado**: candidatos claros hoje são cálculo de valor/tempo de locação e geração de payload PIX (`lib/services/pix_payload.dart` já é praticamente isso). CRUD simples (catálogo, configurações do negócio) vai direto Repository → Cubit, sem use case artificial.
- **`constitution.md` já atualizada** (seções "Stack" e "Arquitetura") para refletir estas decisões — pré-requisito para esta spec poder virar `Approved` foi resolvido.

## Roadmap de fatias (resolve a dúvida de "tudo de uma vez" vs. "guarda-chuva")

Escolhido: guarda-chuva + fatias por feature, cada uma spec própria (`spec.md`/`plan.md`/`tasks.md`), na ordem de risco crescente — foundation e telas simples primeiro, locação (a área mais complexa: timers, notificação, PIX) por último e possivelmente quebrada em sub-fatias na hora.

| # (a criar) | Fatia | Escopo | Risco |
|---|---|---|---|
| 010 (esta) | Fundação | Estrutura de pastas `data/domain/ui`, `flutter_bloc`+`equatable` no `pubspec.yaml`, `lib/models/` → `lib/domain/models/` (só mover, sem criar Cubit/View ainda) | Muito baixo |
| 011 | Configurações do negócio | `business_settings_screen.dart` → `BusinessSettingsRepository` + `BusinessSettingsCubit` + View | Baixo — 1 tela, CRUD simples, bom primeiro Cubit real pra validar o padrão |
| 012 | Catálogo — criação de brinquedo | `add_toy_sheet.dart` → `ToyRepository` + `ToyCatalogCubit` + View. **Não inclui `catalog_tab.dart`** — ver nota de aprendizado abaixo. | Baixo |
| 013 | Relatório | `report_tab.dart` → provavelmente só leitura derivada de `RentalRepository`, sem Cubit próprio ou com um Cubit fino | Baixo |
| 014 | Locação (nova/ativa/encerrar) + PIX + notificações + grade do catálogo | `home_tab.dart`, `active_tab.dart`, `new_rental_sheet.dart`, `end_rental_dialog.dart`, `lib/services/pix_payload.dart`, `lib/notifications/*`, **e `catalog_tab.dart`** → `RentalRepository` + `Cubit`(s) de locação, `Service`s de PIX/notificação | Alto — timers, notificação local, PIX; migrar por último e considerar sub-fatiar (ex.: criar locação vs. encerrar/timer) no `plan.md` de quando chegar lá |

Cada fatia só começa quando a anterior estiver `Implemented` (constitution: zero-breakage, sem duas fatias arquiteturais em paralelo). Números exatos (011, 012...) confirmados na hora de criar cada pasta, respeitando a numeração sequencial do `specs/README.md`.

**Aprendizado da fatia 012** (2026-08-23, ajuste permitido pela dúvida não-bloqueante já registrada abaixo): `catalog_tab.dart` (a grade com os "tickets" de disponibilidade) chama `AppState.toyAvailable(Toy)`, que cruza `Toy.qty` com `rentals` ativas — uma consulta genuinamente cross-repository (`Toy` + `Rental`), não resolvível só com `ToyRepository`. Como `RentalRepository` só existe na fatia 014, mover `catalog_tab.dart` pro `ToyCatalogCubit` agora exigiria ou (a) o Cubit depender de `AppState` (inverte a direção da migração) ou (b) uma dependência prematura em locação. Decisão: `add_toy_sheet.dart` (criação pura de brinquedo, sem tocar em locação) migra na 012; `catalog_tab.dart` migra junto da 014, quando um pequeno `ComputeToyAvailability` (use case cross-repository, `ToyRepository` + `RentalRepository`) resolve isso de forma limpa.

## Fora de escopo (desta spec 010 especificamente)

- Migrar qualquer tela, `Cubit` ou lógica de negócio — isso é o roadmap acima, cada item em spec própria.
- Riverpod, GetX e Bloc "evento puro" como state management — não avaliados, `constitution.md` já veda sem atualização própria.
- Qualquer mudança de comportamento visível, layout ou fluxo de tela.
- Adicionar backend, persistência remota ou nova permissão — vedado pela constitution sem revisão de segurança dedicada.

## Cenários de usuário

Esta spec (010) só move `lib/models/` para `lib/domain/models/` e prepara estrutura/dependências — não há comportamento novo:

1. Dado qualquer fluxo hoje suportado pelo app, quando a fundação (pastas, dependências, modelos movidos) é aplicada, então o app se comporta de forma idêntica ao usuário (mesma UI, mesmos dados, mesmos alertas/notificações).
2. Dado um teste de widget/integration já existente em `test/`, quando a fundação é aplicada, então o teste continua passando sem alteração de asserts (só pode mudar import se necessário, por causa do novo caminho de `lib/domain/models/`).

Comportamento observável de cada feature migrada (011+) é coberto na spec daquela fatia, com o mesmo critério de paridade.

## Critérios de aceite (desta spec 010)

- [x] `constitution.md` atualizada: "Arquitetura" com as camadas `data/domain/ui`, "Stack" com `flutter_bloc`/`Cubit`/`equatable`.
- [x] `flutter_bloc` e `equatable` adicionados ao `pubspec.yaml`.
- [x] Estrutura de pastas criada: `lib/data/{repositories,services}/`, `lib/domain/{models,use_cases}/`, `lib/ui/{core,features}/`.
- [x] `lib/models/` (Toy, Rental, BusinessSettings) movidos para `lib/domain/models/`, com todos os imports atualizados (`lib/state/app_state.dart`, screens, widgets, tests).
- [x] `lib/models/` removido (pasta vazia após a migração).
- [x] Roadmap de fatias (tabela acima) refletido em `specs/README.md` como próximos itens do backlog.
- [x] `flutter analyze` limpo.
- [x] Toda a suíte de testes em `test/` passa sem alterar comportamento esperado (40 testes, todos verdes).
- [x] App builda e roda igual a antes (nenhuma tela, Cubit ou lógica de negócio migrada ainda nesta spec).

## Requisitos não-funcionais

- Zero regressão de comportamento (regra de não-quebra da constitution) — cada fatia migrada precisa manter `flutter analyze` limpo e testes verdes antes de avançar para a próxima.
- Migração incremental: app tem que continuar buildando e rodando a cada fatia (feature/tela) migrada, não só no final.
- Testabilidade: `Cubit`s e `Repository`s devem ser testáveis sem `WidgetTester` (unit test puro, incluindo `bloc_test` para asserts de sequência de estado do `Cubit`), o que hoje não é totalmente possível com lógica presa em `AppState`+widgets.

## Opções de gerenciamento de estado avaliadas (camada ViewModel)

A skill de arquitetura pede `ViewModel extends ChangeNotifier` por padrão; comparamos as 3 opções reais pro projeto antes de decidir. Nas 3, `Repository`/`Service` (camada `data/`) ficam iguais — a diferença é só como o `ViewModel`/tela expõe e reage a estado.

| Critério | `provider` (ChangeNotifier) — anterior | Cubit (`flutter_bloc`) | Bloc (`flutter_bloc`) |
|---|---|---|---|
| Já usado no projeto | Sim, em todo o app até aqui | Não — dependência nova | Não — dependência nova |
| Precisa atualizar `constitution.md` (seção Stack)? | Não | Sim (feito) | Sim |
| Modelo de mutação de estado | Métodos chamam `notifyListeners()`; estado mutável por padrão | Métodos chamam `emit(novoEstado)`; incentiva estado imutável | Eventos (`add(Evento)`) → `Bloc` processa e `emit(novoEstado)`; totalmente imutável e unidirecional |
| Boilerplate | Baixo | Médio (classes de estado por feature) | Alto (classes de evento + estado por feature) |
| Curva de aprendizado / custo de migração | Nenhuma | Média — muda o jeito de escrever cada ViewModel, mas API pequena | Alta — muda modelo mental pra evento/estado em todo o app |
| Testabilidade | Boa | Muito boa (`bloc_test`, assert de sequência de estados) | Muito boa, mas testa também sequência de eventos |
| Encaixe com o que o app tem hoje (timers de locação/notificação, PIX, catálogo) | Já resolve tudo isso sem atrito | Estados como `RentalRunning(remaining)`, `RentalExpired` ficam explícitos | Ganho (rastreabilidade de eventos, replay) só compensa se o fluxo virar bem mais complexo do que é hoje |
| Risco pra migração incremental (fatiada por feature) | Baixo | Baixo/médio — duas libs de state coexistindo durante a transição | Baixo/médio — mesmo trade-off do Cubit, com mais código por fatia |

**Decisão: Cubit.** Ver "Decisões" acima.

## Dúvidas em aberto

Nenhuma bloqueando `Approved` no momento — todas as dúvidas anteriores (conflito com constitution, fatiamento, repository por domínio, use cases, freezed vs. mão) foram resolvidas acima. Ponto em aberto não-bloqueante:

1. A ordem exata das fatias 011–014 (tabela do roadmap) pode ser ajustada conforme o aprendizado da fatia 011 (primeiro Cubit real) — se aparecer atrito inesperado, o roadmap é atualizado antes de criar a próxima pasta de spec, não durante uma fatia em andamento.
