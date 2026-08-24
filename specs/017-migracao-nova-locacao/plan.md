# Plan: Migração — Nova locação

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Primeira fatia de locação de verdade, e a primeira onde o dado de UI (`draft`) genuinamente não pode/deve ser compartilhado entre os dois mundos — só o resultado (`Rental` criada) compartilha fonte única, via `RentalRepository`. Isso é diferente do padrão de proxy usado em 011/012/013: aqui os dois "rascunhos" coexistem de propósito.

1. **`lib/domain/formatters.dart`** — move de `lib/ui/core/formatters.dart` (descoberto necessário porque `ScheduleRentalEndNotifications`, camada `domain`, precisa de `formatMoney` pro corpo da notificação — um Use Case não pode importar de `lib/ui/`). `AppState` e `ReportView` (únicos 2 consumidores) trocam o import.
1b. **Mesmo problema, descoberto no mesmo passo**: `RentalNotifier` (interface) e `notification_texts.dart` (textos) estavam em `lib/data/services/` desde a spec 016 — mas são exatamente o tipo de abstração que um Use Case de domínio precisa referenciar (`RentalNotifier` é um *port*, `notification_texts.dart` é regra de negócio de copy, nenhum dos dois embrulha uma API externa de verdade). Os dois movem pra `lib/domain/` também. `lib/data/services/local_rental_notifier.dart` (a implementação real, que sim embrulha `flutter_local_notifications`) fica onde está — é o único dos três que é genuinamente um `Service`.
2. **`ScheduleRentalEndNotifications`** (`lib/domain/use_cases/`) — extrai a lógica de `AppState._scheduleEndNotification` sem mudar nada: `call(Rental rental, Toy toy, RentalNotifier notifier)`. `AppState._scheduleEndNotification` vira uma casca fina que chama isso.
3. **`RentalRepository.addNew(...)`** — mesma responsabilidade que `ToyRepository.addNew` já tem: monta a `Rental` (gera o id) e chama `add(...)`. `AppState.submitNew()` passa a usar isso em vez de montar `Rental(...)` manualmente — mesmo id, mesmos campos, comportamento idêntico (coberto pelos ~10 arquivos de teste que chamam `submitNew()` direto).
4. **`NewRentalCubit`** (`lib/ui/features/rental/view_models/`) — construtor com `ToyRepository`, `RentalRepository`, `RentalNotifier?` (opcional, mesmo padrão de `AppState`), `ComputeToyAvailability` (default `const`). Estado próprio (`NewRentalDraftState`, `Equatable`) espelha os campos de `RentalDraft`, mais `toys`/`availability` (pro dropdown) — computados como no `ToyCatalogCubit`/`ReportCubit`. Métodos: `open()` (reseta o rascunho — primeiro brinquedo disponível, mesma regra de `AppState.openNew`), `setToy`/`setChildName`/`setGuardianName`/`setGuardianPhone`/`applyDuration`/`setPrice`/`setOpenEnded`/`setCustomRate`, `submit()` (usa `RentalRepository.addNew` + `ScheduleRentalEndNotifications`, retorna a `Rental` criada). Escuta `ToyRepository`/`RentalRepository` (disponibilidade pode mudar com o formulário aberto).
5. **`NewRentalSheetView`** — cópia de `new_rental_sheet.dart`, trocando `AppState` por `NewRentalCubit` em tudo. Mesmas `TestKeys`.
6. **`modal_launchers.dart`**: `showNewRentalSheet` chama `context.read<NewRentalCubit>().open()` em vez de `state.openNew()`/`closeNew()` (confirmado sem uso: `AppState.showNew` nunca é lido por nenhuma `Widget`, só setado — grep feito antes de decidir).
7. **`main.dart`**: `BlocProvider<NewRentalCubit>` novo.
8. Remove `lib/widgets/new_rental_sheet.dart`.

## Arquivos afetados

- `lib/domain/formatters.dart` — novo (movido de `lib/ui/core/formatters.dart`).
- `lib/domain/use_cases/schedule_rental_end_notifications.dart` — novo.
- `lib/data/repositories/rental_repository.dart` — ganha `addNew(...)`.
- `lib/state/app_state.dart` — `submitNew()`/`_scheduleEndNotification` refatorados por dentro (mesma API pública); import de formatters atualizado.
- `lib/ui/features/report/views/report_view.dart` — import de formatters atualizado.
- `lib/ui/features/rental/view_models/new_rental_state.dart` — novo.
- `lib/ui/features/rental/view_models/new_rental_cubit.dart` — novo.
- `lib/ui/features/rental/views/new_rental_sheet_view.dart` — novo (movido de `new_rental_sheet.dart`).
- `lib/widgets/new_rental_sheet.dart` — removido.
- `lib/widgets/modal_launchers.dart` — `showNewRentalSheet` usa o novo Cubit/View.
- `lib/main.dart` — `BlocProvider<NewRentalCubit>`.
- `test/new_rental_cubit_test.dart` — novo.

## Modelo de dados / estado

`NewRentalDraftState` novo (Equatable) — não confundir com `RentalDraft` (classe mutável que `AppState` continua usando pro seu próprio rascunho, inalterada). Nenhum domain model muda.

## Riscos / dependências

- Maior risco desta fatia: os ~10 arquivos de teste que chamam `state.submitNew()`/`state.setDraftXxx()` direto — nenhum pode quebrar. Mitigado por não tocar a assinatura pública desses métodos, só a implementação interna de `submitNew`/`_scheduleEndNotification` (e ambas já têm cobertura de teste que pega qualquer desvio de comportamento: `rental_notifications_test.dart`, `extend_rental_test.dart`, etc.).
- `test/open_ended_rental_test.dart`'s teste de UI ("Nova locação sheet toggles...") é a única cobertura de widget que já dirige o formulário — crítico não quebrar.
- Depende de 012 (`ToyCatalogCubit`/`ComputeToyAvailability`), 013 (`RentalRepository`), 016 (`Services` já em `lib/data/services/`).

## Alternativas consideradas

- **Compartilhar um único rascunho entre `AppState` e `NewRentalCubit`.** Descartado — o rascunho é estado de UI efêmero (não é dado persistido nem lido por mais de uma tela ao mesmo tempo), diferente de `Toy`/`Rental`/`BusinessSettings`, que são dados de domínio genuinamente compartilhados. Dois rascunhos independentes não criam risco de divergência porque nada mais lê o rascunho de `AppState` uma vez que a UI migrou.
- **Deixar `formatMoney` em `lib/ui/core/` e o Use Case duplicar a formatação.** Descartado — duplicar uma função de 1 linha pareceria inofensivo, mas o padrão do projeto até aqui sempre extraiu em vez de duplicar (spec 014); mover pra `lib/domain/` resolve a causa raiz (a função nunca devia estar em `ui/core/` pra começo de conversa — é pura, sem `BuildContext`, sem widget).
