# Plan: Notificação de tempo esgotado reformatada + aviso prévio de 5 min

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

`notification_texts.dart` ganha os novos textos (puro, sem lógica de agendamento — mesma responsabilidade de hoje). `RentalNotifier` ganha um segundo par schedule/cancel (`*EndingSoon`) ao lado do existente (`*RentalEnd`) — dois métodos explícitos em vez de um parâmetro "kind", pra manter a interface simples e o `FakeRentalNotifier` de teste continua registrando cada tipo separadamente (dois mapas). `LocalRentalNotifier` usa um id de notificação derivado diferente pro aviso prévio (`'${rentalId}_soon'.hashCode`), senão ele se sobrescreveria com o de fim (mesmo `rentalId`).

`AppState._scheduleEndNotification` — já é o único lugar que agenda (chamado por `submitNew` e `extendActive`) — passa a agendar as duas. `cancelActive`/`confirmEnd`/`extendActive` (antes de reagendar) cancelam as duas. Nenhuma mudança de assinatura pública além dessas.

Formatação de horário `HH:mm`: helper local `_pad2` (mesmo padrão de `fmtClock`), sem trazer `intl` pro projeto.

## Arquivos afetados

- `lib/notifications/notification_texts.dart` — `rentalEndedNotificationText` ganha parâmetros novos; nova função `rentalEndingSoonNotificationText`.
- `lib/notifications/rental_notifier.dart` — `scheduleRentalEndingSoon`/`cancelRentalEndingSoon` na interface.
- `lib/notifications/local_rental_notifier.dart` — implementação real das duas, com id de notificação distinto do de fim; `AndroidNotificationDetails` com `BigTextStyleInformation` pro corpo de duas linhas da notificação de fim não truncar.
- `lib/state/app_state.dart` — `_scheduleEndNotification` agenda as duas; `cancelActive`/`confirmEnd`/`extendActive` cancelam as duas.
- `test/fakes/fake_rental_notifier.dart` — dois mapas (`scheduled`/`scheduledEndingSoon`), implementa os métodos novos.
- `test/rental_notifications_test.dart` — cobre os cenários novos (aviso prévio agendado, duração curta não agenda aviso, cancelar/finalizar remove as duas).
- `test/extend_rental_test.dart` — cobre `extendActive` reagendando as duas.

## Modelo de dados / estado

Nenhum campo novo em `Rental`/`Toy`. Só formatação de texto e um segundo par schedule/cancel na camada de notificação.

## Riscos / dependências

- Dois ids de notificação por rental (fim + aviso) precisam ser estáveis e não colidir entre si nem com o de outro rental — `_idFor` já é determinístico a partir do `rentalId`; o aviso usa uma chave derivada (`'${rentalId}_soon'`) pro mesmo hash determinístico, sem mapa extra em memória.
- `extendActive` já cancela-e-reagenda a notificação de fim (spec 008) — só precisa fazer o mesmo com a de aviso prévio, sem lógica nova de reagendamento.
- Locação com duração ≤ 5 min: o aviso prévio cairia em `startedAt` ou antes — a guarda existente em `LocalRentalNotifier.scheduleRentalEnd` (`if (!at.isAfter(DateTime.now())) return;`) já cobre isso pro método de fim; o novo `scheduleRentalEndingSoon` replica a mesma guarda.

## Alternativas consideradas

- Um único método `scheduleRentalEnd` com um parâmetro `NotificationKind` — descartado: mais indireção pra um caso de só 2 tipos fixos, interface mais simples com dois métodos nomeados.
- Deep link ao tocar na notificação — descartado nesta spec (decisão registrada), maior escopo (callback de resposta + navegação com app fechado).
