# Spec: Migração — Nova locação

Status: Implemented
Criado: 2026-08-24

Primeira sub-fatia de locação do roadmap em [specs/010-migracao-arquitetura-camadas](../010-migracao-arquitetura-camadas/spec.md) (ver "Aprendizado da fatia 016"). Migra só o formulário "Nova locação" (`new_rental_sheet.dart`) — não toca em `active_tab.dart`/`end_rental_dialog.dart`/`home_tab.dart`, que ficam pra sub-fatias seguintes.

## Problema

`new_rental_sheet.dart` lê/grava tudo em `AppState.draft` (`setDraftToy`/`setDraftChild`/`setDraftGuardian`/`setDraftPhone`/`applyDuration`/`setDraftPrice`/`setDraftOpenEnded`/`setDraftCustomRate`/`submitNew`/`ratePerMinute`/`toys`/`toyAvailable`/`toyById`/`fmtMoney`).

Diferente de todas as fatias anteriores, aqui **não dá pra remover nem proxyar** esses membros de `AppState` — `state.draft`/`setDraftXxx`/`applyDuration`/`submitNew`/`ratePerMinute` são chamados **diretamente por ~10 arquivos de teste** (`rental_notifications_test.dart`, `extend_rental_test.dart`, `extend_time_widget_test.dart`, `catalog_tickets_test.dart`, `open_ended_rental_test.dart`, `design_v3_test.dart`, `full_app_journey_test.dart`) como atalho pra criar uma locação de teste sem passar pela UI. Esses testes continuam existindo e não podem quebrar.

## Objetivo

`new_rental_sheet.dart` vira `NewRentalCubit` + `NewRentalSheetView` (`lib/ui/features/rental/`), com seu **próprio** rascunho de formulário (independente de `AppState.draft` — são dois rascunhos de UI paralelos, não um dado de domínio que precise de fonte única), gravando a locação nova direto no `RentalRepository` compartilhado. `AppState.draft`/`setDraftXxx`/`applyDuration`/`submitNew`/`ratePerMinute`/`openNew`/`closeNew` **continuam existindo, sem mudar de assinatura nem comportamento observável** — só o `submitNew()` é refatorado por dentro (constrói a `Rental` via um `RentalRepository.addNew(...)` novo, em vez de montar o objeto na mão), pra não duplicar a regra de geração de id entre os dois mundos.

Também elimina duplicação que apareceria entre `AppState._scheduleEndNotification` e o `NewRentalCubit`: a lógica de agendar as duas notificações (spec 005 + spec 009) vira um Use Case (`ScheduleRentalEndNotifications`, `lib/domain/use_cases/`) — primeiro caso de um Use Case reusado por mais de um Cubit/consumidor, exatamente o critério que a spec 010 previu.

`lib/ui/core/formatters.dart` muda de lugar pra `lib/domain/formatters.dart`: o Use Case novo precisa de `formatMoney` (pro corpo da notificação de fim de locação) e um Use Case (camada `domain`) não pode depender de `lib/ui/` — só descoberto ao implementar esta fatia, corrige um desalinhamento de camada da spec 014.

## Fora de escopo

- `home_tab.dart` — o FAB "Nova locação" já mora em `home_shell.dart` (nível do shell, não da aba), então não precisa migrar junto.
- `active_tab.dart`, `end_rental_dialog.dart`, `pix_qr_sheet.dart` — sub-fatias seguintes.
- Qualquer mudança de comportamento visível, layout ou cópia de texto.
- Trocar a fórmula de cálculo de preço/duração/taxa — só reorganização de onde o código mora.

## Cenários de usuário

Paridade total:

1. Dado o operador toca no "+", quando o formulário "Nova locação" abre, então vê os mesmos campos, o mesmo brinquedo pré-selecionado (primeiro disponível) e os mesmos presets de duração — idêntico a hoje.
2. Dado o formulário aberto, quando o operador alterna "Tempo fixo" ↔ "Tempo corrido", então os campos mostrados mudam exatamente como hoje (cenário já coberto por `test/open_ended_rental_test.dart`, não pode quebrar).
3. Dado o formulário preenchido, quando o operador confirma "Iniciar locação", então a locação aparece imediatamente na aba "Em andamento" (ainda em `AppState`, mundo antigo) — prova de que os dois mundos compartilham o mesmo `RentalRepository`.
4. Dado uma locação de duração fixa criada, quando o horário de término chega, então as notificações (fim + aviso de 5 min) continuam sendo agendadas exatamente como hoje.

## Critérios de aceite

- [x] `lib/domain/formatters.dart` — `formatMoney`/`formatRelativeTime` movidos de `lib/ui/core/formatters.dart` (mesmo conteúdo). `AppState`/`ReportView` (únicos consumidores hoje) atualizados. Mesmo motivo levou `rental_notifier.dart`/`notification_texts.dart` de `lib/data/services/` pra `lib/domain/` também (só `local_rental_notifier.dart` — a implementação real — é um `Service` de verdade).
- [x] `ScheduleRentalEndNotifications` (`lib/domain/use_cases/`) — mesma lógica que `AppState._scheduleEndNotification` tinha (agenda "fim" + "faltam 5 min", pula se `isOpenEnded`). `AppState._scheduleEndNotification` passa a delegar pra ele (refatoração interna, comportamento idêntico).
- [x] `RentalRepository` ganha `addNew(...)` (mesmo esquema de id `r<microssegundos>` que `AppState.submitNew` sempre usou) — `AppState.submitNew()` passa a chamar esse método em vez de montar `Rental(...)` na mão (refatoração interna, mesma saída).
- [x] `NewRentalCubit` + estado (`lib/ui/features/rental/view_models/`) — rascunho de formulário próprio (toy, nome da criança, responsável, telefone, duração/preço ou tempo corrido/taxa), injeta `ToyRepository` + `RentalRepository` (+ disponibilidade via `ComputeToyAvailability`, já existente) + um `RentalNotifier` (opcional, mesmo padrão de `AppState`). `submit()` grava via `RentalRepository.addNew(...)` e agenda notificação via `ScheduleRentalEndNotifications`.
- [x] `NewRentalSheetView` (`lib/ui/features/rental/views/`) substitui `lib/widgets/new_rental_sheet.dart` — mesmo layout, mesmas `TestKeys`.
- [x] `lib/widgets/modal_launchers.dart` (`showNewRentalSheet`) usa o novo Cubit/View — não chama mais `AppState.openNew()`/`closeNew()` (confirmado sem uso em nenhuma UI: `showNew` nunca é lido por nenhum widget).
- [x] `AppState.draft`/`setDraftToy`/`setDraftChild`/`setDraftGuardian`/`setDraftPhone`/`applyDuration`/`setDraftPrice`/`setDraftOpenEnded`/`setDraftCustomRate`/`submitNew`/`ratePerMinute`/`openNew`/`closeNew` continuam com a mesma assinatura pública — nenhum teste que os chama diretamente mudou.
- [x] `main.dart` registra `BlocProvider<NewRentalCubit>`.
- [x] Teste novo (unit, sem `WidgetTester`) cobrindo `NewRentalCubit`/`RentalRepository.addNew`/`ScheduleRentalEndNotifications`.
- [x] `flutter analyze` limpo.
- [x] Toda a suíte de testes existente passa sem alterar nenhum assert (79 testes, todos verdes) — `test/open_ended_rental_test.dart` (o único teste widget que já dirigia a UI do formulário) e os ~10 arquivos que chamam `state.submitNew()`/`state.setDraftXxx` direto continuam passando sem mudança.

## Requisitos não-funcionais

- `NewRentalCubit`/`ScheduleRentalEndNotifications`/`RentalRepository.addNew` testáveis com `flutter_test` puro, sem `WidgetTester`.
- Nenhuma duplicação nova entre `AppState` e `NewRentalCubit` além do que já é inevitável (dois rascunhos de formulário paralelos, por design).

## Dúvidas em aberto

Nenhuma bloqueante.
