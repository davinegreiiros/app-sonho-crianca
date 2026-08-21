# Plan: Notificações locais de fim de locação

Referência: [spec.md](spec.md), [specs/002-seguranca-dados/spec.md](../002-seguranca-dados/spec.md).

## Abordagem técnica

1. **Dependência.** `flutter_local_notifications` — mantida ativamente, sem chamada de rede, é o padrão de facto pra notificação local no Flutter.
2. **Mensagens centralizadas.** `lib/notifications/notification_texts.dart`: função `rentalEndedNotification(childName, toyName)` retornando `(title, body)` em pt-BR — único lugar que decide o texto (spec já registrou a decisão: brinquedo + nome da criança), fácil de ajustar sem tocar em lógica de agendamento.
3. **Serviço de agendamento.** `lib/notifications/rental_notifications.dart`: classe `RentalNotificationService` envolvendo `FlutterLocalNotificationsPlugin` — `init()` (canal Android + permissão), `scheduleForRental(Rental, Toy)` (agenda pro horário `startedAt + durationMin`; não-op se `rental.isOpenEnded`, spec 006, já que não há horário-alvo), `cancelForRental(String rentalId)`. Usa `rental.id.hashCode` como id numérico da notificação (determinístico, permite cancelar depois).
4. **Testabilidade.** `RentalNotificationService` recebe o `FlutterLocalNotificationsPlugin` (ou uma interface própria mínima) injetado — em teste, um fake registra quais ids foram agendados/cancelados, sem precisar de canal de plataforma real. Isso é o que faz o critério de aceite "agendar cria 1 notificação; cancelar/finalizar remove" ser testável em `flutter test`.
5. **Integração em `AppState`.** Instância de `RentalNotificationService` injetada no construtor (default real, fake nos testes — mesmo padrão de injeção que já se cogitou pra `SharedPreferences` em `004`, mas aqui é explícito desde já pra não repetir o problema de acoplamento direto a plugin). Chamadas:
   - `submitNew()`: depois de criar a `Rental`, `notifications.scheduleForRental(rental, toy)` (pulado se tempo corrido).
   - `cancelActive(id)`: `notifications.cancelForRental(id)` antes de remover.
   - `confirmEnd()`: `notifications.cancelForRental(endingId)` antes de `finish()` — encerrar manualmente antes do tempo acabar também cancela a notificação agendada.
6. **Permissão em runtime.** Pedida só na primeira vez que `scheduleForRental` é chamado de verdade (não no boot do app) — `RentalNotificationService` pede `requestNotificationsPermission()` (Android 13+/iOS) lazily, uma vez, com uma flag interna pra não pedir de novo.
7. **Manifest.** `POST_NOTIFICATIONS` (Android) — `flutter_local_notifications` cuida do resto via seu próprio merge de manifest (ícone, receiver de boot não é necessário aqui, já que não precisamos sobreviver a reboot do aparelho pra esta versão).

## Arquivos afetados

- `pubspec.yaml` — `flutter_local_notifications`.
- `lib/notifications/notification_texts.dart` — novo.
- `lib/notifications/rental_notifications.dart` — novo (serviço + interface mínima pra fake de teste).
- `lib/state/app_state.dart` — injeção do serviço, chamadas em `submitNew`/`cancelActive`/`confirmEnd`.
- `android/app/src/main/AndroidManifest.xml` — `POST_NOTIFICATIONS` (revisado contra `002`).
- `test/` — teste do serviço com fake plugin (agenda/cancela), teste de integração leve via `AppState` (criar agenda, cancelar/finalizar remove).

## Modelo de dados / estado

Nenhuma mudança em `Rental`/`Toy` — o id numérico da notificação é derivado (`rental.id.hashCode`), não armazenado.

## Riscos / dependências

- Depende de `002` (permissão mínima, sem PII de responsável na notificação, timing do pedido de permissão).
- Depende de `006` (tempo corrido) pra saber quando **não** agendar (`isOpenEnded`).
- Notificação real de SO não é testável em `flutter test` — validação de "dispara de verdade com o app em segundo plano" fica pra verificação manual (`/run` num device/emulador), documentado como tal no critério de aceite.

## Alternativas consideradas

- Agendar a notificação só quando o app vai pra segundo plano (`AppLifecycleState`): descartado — mais simples e robusto agendar sempre na criação e cancelar sempre que a locação sai do estado "ativa esperando o tempo acabar", não importa se o app está em primeiro ou segundo plano nesse momento.
