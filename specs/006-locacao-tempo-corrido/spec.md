# Spec: Locação em tempo corrido (sem tempo fixo, valor calculado no fim)

Status: Draft
Criado: 2026-08-15

## Problema

Hoje toda locação nasce com `durationMin` e `price` fixos, escolhidos na hora de abrir (`RentalDraft`, `applyDuration`/`setDraftPrice` em `app_state.dart:173-184`) — o contador em "Em andamento" só conta regressivo até esse tempo (`fmtClock`/`remainMin`, `active_tab.dart:80-85`). Pra brinquedo cobrado por tempo livre (ex: cama elástica a R$ 8 a cada 10 min, mas a criança fica o tempo que quiser), isso não serve: o operador teria que adivinhar a duração e criar de novo se passar.

## Objetivo

Qualquer brinquedo pode ser alugado em modo "tempo corrido": sem duração pré-definida, o relógio conta *pra cima* desde o início, e o valor final é calculado automaticamente na hora de finalizar, com base na taxa por minuto do brinquedo (`price`/`blockMin`) multiplicada pelo tempo realmente decorrido. Exemplo: Cama Elástica é `blockMin: 30`, `price: 15` → R$ 0,50/min; ficou 22 min → R$ 11,00.

## Fora de escopo

- Mudar a régua de preço/bloco dos brinquedos existentes (o "tempo corrido" só *deriva* a taxa por minuto do preço/bloco já cadastrado, não pede um preço novo por minuto).
- Cobrança progressiva/degrau (ex: primeiros 10 min a um preço, minutos extras a outro) — é linear, mesma taxa o tempo todo.
- Tempo corrido com múltiplos brinquedos numa mesma locação — continua 1 brinquedo por locação, igual hoje.

## Cenários de usuário

1. Dado o operador abrindo "Nova locação", quando ele marca a locação como "tempo corrido" em vez de escolher um preset de minutos, então os campos de duração/preço fixos somem/desabilitam e a locação inicia sem tempo definido.
2. Dado uma locação em tempo corrido ativa, quando o operador olha "Em andamento", então vê um relógio contando *pra cima* (tempo decorrido) e uma estimativa de valor atualizando ao vivo, em vez do contador regressivo e progresso de barra que as locações de tempo fixo têm.
3. Dado uma locação em tempo corrido de 22 minutos decorridos num brinquedo de taxa R$ 0,50/min, quando o operador finaliza, então o valor cobrado calculado é R$ 11,00 — determinístico, testável, sem depender de quando exatamente o botão foi clicado dentro do mesmo minuto (ver regra de arredondamento nas dúvidas em aberto).
4. Dado uma locação em tempo corrido, quando o operador cancela em vez de finalizar (`cancelActive`), então não há cobrança — igual já funciona hoje pra locação de tempo fixo cancelada.
5. Dado o relatório de faturamento (`ReportTab`), quando uma locação em tempo corrido já finalizada aparece nele, então ela soma no total e no detalhamento por brinquedo/pagamento normalmente — `reportTotal`/`toyBreakdown` (`app_state.dart:314-333`) não podem distinguir tempo corrido de tempo fixo, é só mais uma locação com `price` preenchido.
6. Dado que não existe conceito de "estourou o tempo" numa locação sem tempo definido, quando o operador olha o card dela, então não aparece cor de urgência/overtime (`statusColor`, `app_state.dart:103`) — isso é exclusivo de locação com prazo.

## Critérios de aceite

- [ ] `Rental` ganha um jeito de representar "sem duração fixa" (ex: `durationMin` nullable, ou campo `openEnded: bool` — decidir no `plan.md` olhando todo lugar que hoje assume `durationMin` não-nulo: `fmtClock`, `statusColor`, `StripedProgress`, `_reportCutoff` não usa isso mas `recentActivity`/`historyList` usam `endedAt`, que continua existindo igual).
- [ ] `AppState` ganha a taxa por minuto derivada (`toy.price / toy.blockMin`), sem exigir campo novo no `Toy` — é cálculo, não dado novo cadastrado.
- [ ] `NewRentalSheet` ganha alternância "tempo fixo" / "tempo corrido"; em tempo corrido os presets de minuto (`10/15/30/60`) e o campo de valor manual (`setDraftPrice`) ficam desabilitados/ocultos — não faz sentido escolher preço quando ele é calculado no fim.
- [ ] `ActiveTab`/`_ActiveCard` (`active_tab.dart:72`) ganha variante visual pra tempo corrido: cronômetro crescente em vez de regressivo, sem `StripedProgress` de percentual (não há "100%" possível sem duração) — mas mantendo os mesmos botões "Cancelar"/"Finalizar" e o mesmo `TestKeys.activeCardKey`.
- [ ] Valor exibido ao vivo no card (estimativa) usa a mesma taxa que será usada no cálculo final — nunca diverge entre o que o operador vê rodando e o que é cobrado ao finalizar.
- [ ] `confirmEnd()` (`app_state.dart:226`), pra locação em tempo corrido, calcula `price` a partir do tempo decorrido no momento da confirmação antes de chamar `r.finish(...)` — locação de tempo fixo continua com o `price` já definido na criação, comportamento inalterado.
- [ ] Arredondamento: **fração exata em centavos** — tempo decorrido em minutos (com fração, ex: 22,02 min) × taxa por minuto, sem arredondar o tempo; só o valor final é arredondado pra centavo (2 casas decimais, mesma convenção de `fmtMoney`). Coberto por teste unitário com o exemplo do cenário 3 e pelo menos um caso com fração não-trivial (ex: 22min37s).
- [ ] `EndRentalDialog` mostra o valor final calculado (não o valor "chutado" na criação, que não existe mais pra esse tipo) antes de confirmar a forma de pagamento.
- [ ] Teste de widget/unitário: criar locação em tempo corrido, avançar tempo (fake), finalizar, valor cobrado bate com o cálculo esperado.
- [ ] Teste cobrindo cancelamento de locação em tempo corrido — nenhum valor registrado, some da lista igual `cancelActive` já faz.
- [ ] Suite atual (`test/widget_test.dart`, `integration_test/app_test.dart`) segue passando sem alteração de comportamento pra locação de tempo fixo — este é o caso onde a regra de não-quebra da constitution mais importa: é a mudança de modelo de dado mais profunda das 4 features novas.

## Requisitos não-funcionais

- Cálculo de valor é sensível a centavo — usar arredondamento consistente (`round()`/`toStringAsFixed`) igual o resto do app já faz em `fmtMoney`/`applyDuration`, não introduzir uma segunda convenção de arredondamento no código.

## Dúvidas em aberto

- Tempo corrido tem um valor mínimo (ex: nunca cobra menos que 1 bloco `blockMin` mesmo que a criança saia em 2 min), ou é sempre proporcional desde o segundo 1?
- Existe um teto (ex: nunca passa do "preço se fosse o dia todo") ou é ilimitado enquanto o brinquedo estiver com aquela locação?
- Isso se aplica a todo brinquedo do catálogo (qualquer um pode virar tempo corrido na hora de alugar) ou só a alguns marcados como "elegíveis pra tempo corrido" no cadastro?
