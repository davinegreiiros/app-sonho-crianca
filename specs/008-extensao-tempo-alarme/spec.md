# Spec: Adicionar tempo e alarme visual de tempo esgotado

Status: Implemented
Criado: 2026-08-21
Depende de: [specs/005-notificacoes-locais/spec.md](../005-notificacoes-locais/spec.md), [specs/006-locacao-tempo-corrido/spec.md](../006-locacao-tempo-corrido/spec.md)

## Problema

Hoje, numa locação de tempo fixo, quando o tempo acaba o card em "Em andamento" só troca a cor pra vermelho e o relógio continua contando (`+MM:SS` crescente, `fmtClock`/`app_state.dart:190`) — sem nenhum reforço visual adicional além da cor, fácil de não notar numa lista com vários cards. A notificação do sistema (spec 005) deveria complementar isso, mas está sem validação em device real (`specs/005-notificacoes-locais/tasks.md` T10) — na prática o operador relatou não ter percebido o fim do tempo.

Além disso não existe jeito de estender uma locação em andamento: se a criança quer ficar mais tempo, hoje só dá pra deixar passar do tempo (overtime) ou cancelar e criar uma locação nova, perdendo o histórico de uma única locação contínua.

## Objetivo

Uma locação de tempo fixo ativa ganha um botão "+ tempo" com presets de 5/10/15 min que estende a duração e recalcula o preço proporcionalmente; e ao entrar em overtime (tempo esgotado) o card ganha reforço visual mais forte além da cor vermelha já existente, sem depender de som.

## Fora de escopo

- Qualquer mudança na notificação do sistema operacional (spec 005) — investigação/correção do não-disparo em device é bugfix/spec própria, não desta.
- Som/vibração como parte do alarme — decisão registrada: só reforço visual.
- Adicionar tempo em locação "tempo corrido" (spec 006) — não faz sentido, ela já não tem duração fixa pra estender.
- Diálogo/banner modal interrompendo a tela — o reforço fica confinado ao card, não bloqueia a UI.
- Editar/reduzir tempo já definido — só adicionar.

## Cenários de usuário

1. Dado uma locação de tempo fixo ativa, quando o operador toca "+ tempo" e escolhe um preset (5/10/15 min), então a duração da locação aumenta por esse tanto, o preço aumenta proporcionalmente (taxa por minuto do brinquedo × minutos adicionados), o relógio regressivo passa a contar a partir do novo tempo restante, e a notificação de fim (spec 005) é reagendada pro novo horário.
2. Dado uma locação de tempo fixo ativa que ainda não estourou, quando o tempo restante chega a zero, então o card entra em estado de alarme visual mais forte que hoje (além da cor vermelha), sem interromper a navegação do operador.
3. Dado uma locação já em overtime, quando o operador adiciona tempo suficiente pra zerar o overtime, então o card sai do estado de alarme e volta a mostrar contagem regressiva normal.
4. Dado uma locação "tempo corrido" (`isOpenEnded`), quando o operador olha o card dela, então não existe botão "+ tempo" — extensão de tempo é exclusiva de locação com prazo.
5. Dado o operador toca "+ tempo" repetidas vezes, então cada toque soma ao tempo já estendido (cumulativo), sem limite superior definido nesta spec.

## Critérios de aceite

- [ ] `Rental.durationMin` deixa de ser `final` (ou ganha método próprio) pra permitir extensão; `Rental.price` já não é `final` hoje, segue mutável do mesmo jeito.
- [ ] `AppState` ganha `extendActive(String rentalId, int addMinutes)`: soma `addMinutes` ao `durationMin` da locação, soma `ratePerMinute(toy) * addMinutes` ao `price`, reagenda a notificação de fim (`_scheduleEndNotification`, cancelando a anterior antes) — só se aplica a locação `!isOpenEnded`; chamada numa `isOpenEnded` é no-op.
- [ ] `_ActiveCard` (`active_tab.dart`) ganha botão "+ tempo" (só quando `!openEnded`) com presets 5/10/15 min, chamando `extendActive`.
- [ ] Estado de alarme visual: quando `overtime == true`, além da cor vermelha (`statusColor`) e do `StripedProgress` pulsante já existentes, o card ganha reforço adicional visível (ex: ícone de alerta pulsando perto do relógio, ou pulso na borda do card) — usar os componentes de animação já existentes em `lib/widgets/animations/` (ex: `Pulse`) em vez de criar mecanismo novo.
- [ ] Novas chaves em `TestKeys` pros botões de preset (`extendRentalButton(rentalId, minutes)` ou similar), seguindo o padrão já usado (`finishRentalButton`, `cancelRentalButton`).
- [ ] Teste unitário/widget: `extendActive` aumenta `durationMin` e `price` corretamente pro exemplo do cenário 1; chamada em locação `isOpenEnded` não altera nada.
- [ ] Teste widget: card de locação `isOpenEnded` não mostra botão "+ tempo"; card overtime mostra o reforço visual novo.
- [ ] Suite atual (`test/`, `integration_test/`) segue passando sem alteração de comportamento fora do que esta spec pede.

## Requisitos não-funcionais

- Cálculo de preço da extensão segue a mesma convenção de arredondamento já usada em `computeFinalPrice`/`fmtMoney` (2 casas decimais) — não introduzir uma segunda convenção.
- Reforço visual não pode depender de rede nem de plugin novo — só widgets/animações já existentes no app.

## Decisões registradas (2026-08-21, respostas do dono do produto)

- **Alarme:** só reforço visual mais forte, sem som.
- **Presets de tempo:** botões +5/+10/+15 min (sem campo livre).
- **Preço na extensão:** recalcula proporcional (taxa por minuto do brinquedo × minutos adicionados), somado ao preço já fixado.

Sem dúvida em aberto pendente — spec pronta pra `plan.md`.
