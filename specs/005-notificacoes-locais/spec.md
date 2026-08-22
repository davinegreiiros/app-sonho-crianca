# Spec: Notificações locais de fim de locação

Status: Implemented (validado em device real em 2026-08-22, ver `tasks.md` T10)
Criado: 2026-08-15
Depende de: [specs/002-seguranca-dados/spec.md](../002-seguranca-dados/spec.md)

**Decisão de conteúdo (2026-08-15):** a notificação mostra brinquedo + nome da criança (ex: "Sofia · Cama Elástica — tempo esgotado"), decisão explícita do dono do negócio, ciente do trade-off de exposição na tela de bloqueio descrito em `002`. Ver [specs/002-seguranca-dados/spec.md](../002-seguranca-dados/spec.md) pra risco residual aceito.

## Problema

Hoje o único jeito de saber que o tempo de um brinquedo acabou é ficar olhando a aba "Em andamento" — o contador (`fmtClock`, `app_state.dart:109`) só existe visualmente, na tela. Se o operador estiver em outra aba, com o app em segundo plano, ou a tela bloqueada, ele não é avisado. Numa banca com vários brinquedos e crianças, isso significa locação passando do tempo sem ninguém perceber.

## Objetivo

Quando o tempo de uma locação ativa termina, o app dispara uma notificação local — funciona com o app aberto em outra tela (primeiro plano) e com o app em segundo plano/minimizado — usando `flutter_local_notifications`, com textos em pt-BR.

## Fora de escopo

- Notificação com app completamente fechado (kill/force-stop) além do que o SO permitir por alarme agendado — cobrir "background" (app minimizado), não "app morto" forçosamente burlando limitação do SO.
- Push remoto (Firebase Cloud Messaging) — é tudo local, sem servidor, consistente com o app ser 100% offline hoje.
- Notificação de outros eventos (nova locação criada, relatório diário) — só fim de tempo de locação, é o que foi pedido.

## Cenários de usuário

1. Dado uma locação ativa com o app aberto em qualquer aba, quando o tempo dela chega a zero, então uma notificação aparece avisando que aquela locação terminou.
2. Dado uma locação ativa, quando o app vai pra segundo plano (usuário troca de app) antes do tempo acabar, então a notificação ainda dispara no horário certo.
3. Dado uma locação cancelada (`cancelActive`) ou finalizada (`confirmEnd`) antes do tempo acabar, quando o horário que seria de notificação chega, então nenhuma notificação dispara — notificação órfã de locação que não existe mais é bug.
4. Dado duas locações terminando em horários próximos, quando ambas disparam, então cada notificação identifica claramente qual locação é (brinquedo, sem nome da criança — ver `002`), sem uma sobrescrever a outra.
5. Dado o app aberto na tela daquela locação quando ela termina, quando a notificação dispara, então o app já mostra a mudança de estado visual (cor de urgência) simultaneamente — notificação reforça, não substitui, o que a UI já mostra.

## Critérios de aceite

- [ ] `flutter_local_notifications` integrado, com canal Android dedicado (nome/descrição em pt-BR) e permissão `POST_NOTIFICATIONS`/`UNUserNotificationCenter` pedida em runtime assim que o app abre (ver amendment 2026-08-22 abaixo — decisão original era lazy, no primeiro uso; trocada pra boot).
- [ ] Uma notificação é agendada no momento em que uma locação é criada (`submitNew`, `app_state.dart:186`), pro horário exato `startedAt + durationMin`.
- [ ] Notificação é cancelada se a locação for cancelada (`cancelActive`) ou finalizada manualmente antes do tempo acabar (`confirmEnd`) — sem notificação órfã.
- [ ] Texto da notificação identifica brinquedo + nome da criança (decisão registrada acima), sem expor telefone/nome do responsável — esse continua fora da notificação.
- [ ] Mensagens de notificação (título/corpo) centralizadas num único lugar em pt-BR, fácil de ajustar o texto sem mexer em lógica de agendamento — formato de arquivo/estrutura a decidir no `plan.md` (ex: um mapa de strings dedicado; app não usa `intl`/ARB hoje, então isso é decisão nova, não migração de i18n existente).
- [ ] Funciona com o app em segundo plano (validado manualmente via `/run` num device/emulador, já que teste de widget não cobre notificação de SO).
- [ ] Nenhuma chamada de rede envolvida — tudo local (`flutter_local_notifications` não depende de servidor).
- [ ] Teste unitário do agendamento: dado um `AppState`, criar uma locação agenda 1 notificação; cancelar/finalizar remove o agendamento — usando fake/mock do plugin (não dá pra testar notificação real de SO em `flutter test`).
- [ ] Suite atual (`test/widget_test.dart`, `integration_test/app_test.dart`) segue passando sem alteração de comportamento fora do que esta spec pede.

## Requisitos não-funcionais

- Permissão `POST_NOTIFICATIONS` (Android 13+) e, se o agendamento exigir, `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` — ambas revisadas contra `002-seguranca-dados` antes de entrar no manifest.
- iOS: `UNUserNotificationCenter` — permissão pedida no boot (ver amendment abaixo).

## Decisões registradas (2026-08-16)

- **Som/vibração:** padrão do sistema (canal Android sem som/vibração customizados) — menos código, menos superfície de bug, consistente com o resto do SO do operador.
- **Resumo de vencidas:** não é feature desta spec — a aba "Em andamento" já mostra overtime em vermelho/pulsando (`statusColor`/`pulseOnOvertime`), isso já resolve. Se no uso real não bastar, é spec própria depois.

## Amendment (2026-08-22, resposta do dono do produto)

Decisão original era pedir a permissão de forma lazy, só no primeiro agendamento real (evitar pedir sem contexto no boot). Na prática o operador não notou a notificação nem percebeu que a permissão nunca tinha sido concedida. Trocado pra: **permissão pedida assim que o app abre**, dentro do construtor de `AppState` (`notifications.init()`, fire-and-forget — não bloqueia o boot, `init()` já é idempotente e engole os próprios erros). `LocalRentalNotifier` ganhou `debugPrint` nos `catch` (antes totalmente silenciosos) pra dar visibilidade em sessão de validação manual (T10) sobre falha de init/agendamento/cancelamento.

T10 (validação manual em device) segue pendente — esta mudança não a substitui, só dá mais chance/visibilidade de ela funcionar.

Sem dúvida em aberto pendente.
