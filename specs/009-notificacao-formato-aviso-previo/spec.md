# Spec: Notificação de tempo esgotado reformatada + aviso prévio de 5 min

Status: Implemented
Criado: 2026-08-22
Depende de: [specs/005-notificacoes-locais/spec.md](../005-notificacoes-locais/spec.md), [specs/008-extensao-tempo-alarme/spec.md](../008-extensao-tempo-alarme/spec.md)

## Problema

A notificação de "tempo esgotado" (spec 005) hoje só diz `"$childName · $toyName"` / `"Tempo esgotado — hora de finalizar a locação."` — não mostra quanto cobrar nem a duração, obrigando o operador a abrir o app pra saber o valor. E não existe nenhum aviso *antes* do tempo acabar: o operador só fica sabendo quando já estourou, sem chance de avisar o responsável com antecedência.

## Objetivo

A notificação de fim de locação mostra brinquedo, duração e valor a cobrar; e uma segunda notificação, 5 minutos antes do fim, avisa o operador com antecedência — mockup exato fornecido pelo dono do produto:

- **Fim do tempo:** título `"Tempo esgotado · {criança}"`, corpo `"{brinquedo} · {duração} min"` + `"R$ {valor} a receber — toque para cobrar"`.
- **Aviso prévio (5 min antes):** título `"Faltam 5 min · {criança}"`, corpo `"{brinquedo} · encerra {HH:mm} — já pode avisar o responsável"`.

## Fora de escopo

- Deep link / navegação ao tocar na notificação — decisão registrada abaixo: tocar só abre o app normalmente, sem levar a uma tela específica. Fica pra spec própria se vier a ser pedido.
- Locação "tempo corrido" (spec 006) — sem horário de fim definido, nenhuma das duas notificações desta spec se aplica a ela (mesma regra que já vale pra spec 005).
- Mudar o texto de outras notificações (não existem outras hoje).
- Configurar o tempo de antecedência do aviso (5 min é fixo, sem preferência configurável).

## Cenários de usuário

1. Dado uma locação de tempo fixo ativa de 15 min a R$ 10,00, quando o tempo esgota, então a notificação mostra `"Tempo esgotado · {criança}"` / `"{brinquedo} · 15 min"` / `"R$ 10,00 a receber — toque para cobrar"`.
2. Dado a mesma locação, quando faltam exatos 5 minutos pro fim, então uma segunda notificação dispara: `"Faltam 5 min · {criança}"` / `"{brinquedo} · encerra {HH:mm} — já pode avisar o responsável"`, com o horário de fim real (`startedAt + durationMin`) formatado `HH:mm`.
3. Dado uma locação de 5 minutos ou menos, quando ela é criada, então o aviso prévio de 5 min cairia no passado (ou no próprio instante de criação) — não dispara (mesma regra de "nunca agendar no passado" que a notificação de fim já segue).
4. Dado o operador toca "+ tempo" (spec 008) numa locação ativa, quando a duração/preço mudam, então as duas notificações (aviso prévio e fim) são canceladas e reagendadas pros novos horários/valores — nenhuma notificação órfã com dado antigo.
5. Dado a locação é cancelada ou finalizada antes do tempo acabar, quando os horários que seriam de notificação chegam, então nenhuma das duas dispara — mesma regra de "sem notificação órfã" já válida pra notificação de fim (spec 005).
6. Dado uma locação "tempo corrido" (`isOpenEnded`), quando ela é criada, então nenhuma das duas notificações é agendada — sem horário de fim, não há o que avisar.

## Critérios de aceite

- [x] `lib/notifications/notification_texts.dart`: `rentalEndedNotificationText` ganha `durationMin`/`priceFormatted`, produz o novo título/corpo do cenário 1.
- [x] `lib/notifications/notification_texts.dart`: nova função `rentalEndingSoonNotificationText` produz o título/corpo do cenário 2 (formata `HH:mm` a partir do `DateTime` de fim).
- [x] `RentalNotifier` (interface) ganha `scheduleRentalEndingSoon`/`cancelRentalEndingSoon`, espelhando `scheduleRentalEnd`/`cancelRentalEnd` já existentes — implementados em `LocalRentalNotifier` com um id de notificação distinto do de fim (mesmo rental, duas notificações simultâneas não podem se sobrescrever).
- [x] `AppState._scheduleEndNotification` agenda as duas notificações (fim + aviso prévio, este em `endsAt - 5min`) pra locação de duração fixa; `isOpenEnded` continua sem agendar nenhuma.
- [x] `cancelActive`, `confirmEnd` e `extendActive` cancelam **as duas** notificações (fim + aviso prévio) antes de remover/reagendar — sem órfã de nenhum tipo.
- [x] Toque na notificação: comportamento padrão do sistema (abre o app), sem navegação/deep link customizado.
- [x] Teste unitário: agendamento das duas notificações com os textos/horários corretos pro exemplo do cenário 1/2; cenário 3 (duração ≤ 5min não agenda aviso prévio); cenário 4 (extendActive reagenda as duas); cenário 5 (cancelar/finalizar remove as duas); cenário 6 (tempo corrido não agenda nenhuma).
- [x] Suite atual (`test/`, `integration_test/`) segue passando sem alteração de comportamento fora do que esta spec pede.

## Requisitos não-funcionais

- Formatação de valor usa `AppState.fmtMoney` (mesma convenção já usada em toda a UI) — sem segunda convenção de formatação de dinheiro.
- Formatação de horário `HH:mm` é local/sem `intl` (app não usa `intl` hoje, spec 005 já registrou essa decisão) — helper simples de padding, mesmo padrão de `fmtClock`.
- Nenhuma chamada de rede — local, mesma base de `flutter_local_notifications` já usada (spec 005).

## Decisões registradas (2026-08-22, respostas do dono do produto)

- **Toque na notificação:** só abre o app normalmente — sem deep link pra tela/loca­ção específica.
- **Aviso prévio é notificação nova, separada:** duas notificações por locação de tempo fixo (aviso 5 min antes + fim), ambas ausentes em tempo corrido.
- **Antecedência do aviso:** fixa em 5 minutos, sem configuração.

Sem dúvida em aberto pendente — spec pronta pra `plan.md`.
