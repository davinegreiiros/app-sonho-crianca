# Tasks: Notificação de tempo esgotado reformatada + aviso prévio de 5 min

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `lib/notifications/notification_texts.dart`: reformatar `rentalEndedNotificationText` (título/corpo do cenário 1) + nova `rentalEndingSoonNotificationText` (cenário 2).
- [x] T2 — `lib/notifications/rental_notifier.dart`: `scheduleRentalEndingSoon`/`cancelRentalEndingSoon` na interface.
- [x] T3 — `lib/notifications/local_rental_notifier.dart`: implementa as duas, id de notificação distinto do de fim, `BigTextStyleInformation` no corpo de duas linhas.
- [x] T4 — `lib/state/app_state.dart`: `_scheduleEndNotification` agenda as duas; `cancelActive`/`confirmEnd`/`extendActive` cancelam as duas.
- [x] T5 — `test/fakes/fake_rental_notifier.dart`: segundo mapa + métodos novos.
- [x] T6 — `test/rental_notifications_test.dart`: aviso prévio agendado no horário certo com o texto certo; duração ≤5min não agenda aviso; cancelar/finalizar remove as duas.
- [x] T7 — `test/extend_rental_test.dart`: `extendActive` reagenda as duas (fim + aviso) pro novo horário.
- [x] T8 — `flutter analyze` limpo + `flutter test` completo passando + revisão manual dos critérios de aceite do `spec.md`.

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
