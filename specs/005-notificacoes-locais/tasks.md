# Tasks: Notificações locais de fim de locação

Referência: [spec.md](spec.md) + [plan.md](plan.md).

- [x] T1 — `pubspec.yaml`: `flutter_local_notifications`, `timezone`
- [x] T2 — `lib/notifications/notification_texts.dart` (mensagens pt-BR centralizadas)
- [x] T3 — `lib/notifications/rental_notifier.dart` (interface) + `local_rental_notifier.dart` (implementação real)
- [x] T4 — `AndroidManifest.xml`: `POST_NOTIFICATIONS` (única permissão nova, sem `SCHEDULE_EXACT_ALARM` — decisão registrada no `plan.md`)
- [x] T5 — `AppState`: `notifications` injetável, agenda em `submitNew` (pula tempo corrido via `_scheduleEndNotification`), cancela em `cancelActive`/`confirmEnd`
- [x] T6 — permissão pedida no boot dentro do construtor de `AppState` (`notifications.init()`) — trocado de lazy pra boot em 2026-08-22, ver amendment no `spec.md`
- [x] T7/T8 — `test/rental_notifications_test.dart` com `FakeRentalNotifier`: cria agenda 1 notificação (horário exato `startedAt+durationMin`), cancelar remove, finalizar remove, tempo corrido nunca agenda — 4 testes
- [x] T9 — `flutter analyze` limpo, `flutter test` (38 testes) passando — inclui hardening: `LocalRentalNotifier` captura erro de canal de plataforma (necessário pra não quebrar os testes já existentes, que constroem `AppState()` sem injetar fake; ver nota abaixo) e loga via `debugPrint` (2026-08-22) pra dar visibilidade em sessão de validação manual
- [x] T10 — validação manual via `/run` no iPhone físico do usuário (2026-08-22): diálogo de permissão apareceu no boot, notificação chegou no horário certo com o app em segundo plano, confirmado pelo usuário. **Validado.**

**Nota de implementação:** `LocalRentalNotifier` envolve toda chamada de canal de plataforma (`init`/`scheduleRentalEnd`/`cancelRentalEnd`) em `try/catch` silencioso — notificação falhando (permissão negada, canal ausente em teste, peculiaridade de fabricante) nunca pode quebrar o fluxo de criar/cancelar/finalizar locação. Isso também é o que mantém a suíte de testes já existente (que constrói `AppState()` sem injetar `FakeRentalNotifier`) passando sem precisar tocar em 3 arquivos de teste antigos.

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`. Se algo quebrar no meio, parar ali (regra de não-quebra), não emendar.
