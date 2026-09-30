# Spec: Posto do monitor + fechamento de turno + painel administrativo

Status: Implemented
Criado: 2026-09-17

Design fonte: `Revisao de Design v3.dc.html` (projeto Claude Design `c7934e05-8a2f-4e04-97da-98802b6c3a40`), seção "Revisão · turno 3", ids **3a**–**3d**.

## Problema

Hoje qualquer pessoa que pega o tablet vê o app inteiro (catálogo completo, todas as locações de todos os brinquedos) sem nenhuma noção de "quem está usando agora" nem "esse brinquedo é comigo". Isso impede: saber quanto cada brinquedo/monitor faturou no turno, conferir caixa (esperado vs. contado em mãos) ao fim de um turno, e o dono ter uma visão agregada por posto com trilha de quem fez o quê — que é exatamente o que os ids 3a–3d do design v3 propõem.

## Objetivo

Ao abrir o app, quem for usar escolhe um **posto** (= um brinquedo específico) e diz seu nome — ou entra como administrador. No posto, o monitor só vê e mexe no brinquedo dele. Ao encerrar, confere o caixa do turno (esperado vs. contado). O administrador vê a praça inteira: faturamento por posto/monitor e uma trilha de lançamentos somente-leitura.

## Fora de escopo

- **Fila de espera numerada** (mockup 3b mostra "Fila · 3" com crianças aguardando) — introduz conceito novo (criança em espera, antes de virar locação) que não existe hoje. 3b nesta spec mostra só as locações ativas do posto (o que já existe, filtrado por brinquedo), sem lista de espera.
- **Cortesia (locação grátis) e log de mudança de preço na trilha** — a trilha (3d) nesta spec registra só o que o app já faz de verdade: criar locação, encerrar/cobrar locação. "Cortesia" e "mudou preço" no mockup ficam pra spec futura.
- **Trilha de cancelamento** — `ActiveRentalsCubit.cancelActive` hoje **apaga** a locação (`removeById`), sem deixar rastro. Pra aparecer na trilha, cancelar precisaria virar um status preservado (`RentalStatus.cancelled`) em vez de exclusão — mudança de comportamento maior, com ripple em `ReportCubit` e testes existentes. Fica pra spec própria; aqui cancelar continua exatamente como é hoje (exclui, sem gerar lançamento na trilha).
- **Autenticação real / senha por monitor** — nome do posto é texto livre digitado na hora, sem cadastro nem verificação. É convenção de turno (saber quem fez o quê), não segurança de acesso. Login de verdade (JWT por operador) é o que as specs [022](../022-backend-sync-fundacao/spec.md) (app) / `001-fundacao-auth-crud` (backend) já decidiram — fica pra quando o app consumir o backend (spec futura), fora do escopo daqui.
- **Sync entre aparelhos** — tudo local (SQLite, spec [020](../020-persistencia-local/spec.md)). O cenário é um único tablet compartilhado fisicamente na banca, por revezamento de pessoas — não dois aparelhos vendo o mesmo posto ao mesmo tempo.
- **Editar/apagar um lançamento já publicado na trilha** — é somente leitura/imutável, mesmo princípio já usado no cupom Pix (spec 007, id 1c: "depois disso nada pode ser editado — só corrigido por um novo lançamento").
- **Pixel-perfect clone do CSS do mockup** — 3b/3c/3d são implementados com os componentes/estilos Flutter já existentes (`AppColors`/`AppTheme`, cards de locação ativa já usados no app), inspirados no layout do design, não uma recriação 1:1 dos estilos inline do `.dc.html` (que é HTML/CSS solto, não o design system do app).

## Decisões

- **Posto = Toy + monitor + turno.** Novo modelo `Turno`: `id`, `toyId`, `monitorName`, `openedAt`, `closedAt` (`null` = turno aberto), `countedCash` (`null` até fechar). Um único turno aberto por `toyId` a qualquer momento (índice/checagem no Repository).
- **`Rental` ganha 2 campos novos, nulináveis:** `createdByMonitorName` e `finishedByMonitorName`. `null` = criado/encerrado fora de um posto (modo administrador ou dado antigo pré-migração) — coluna nova via migração de schema aditiva no `sqflite` (mesmo padrão de `020-persistencia-local`), sem quebrar dado existente.
- **Sessão de posto não persiste entre reinícios do app.** Ao abrir o app, sempre começa em "escolher posto" (3a) — mesmo se havia um turno aberto (o turno continua aberto no banco; a tela de abrir posto mostra ele como ocupado e permite **retomar** batendo nele, sem precisar digitar o nome de novo, em vez de exigir reentrar do zero).
- **Posto ocupado na lista (3a):** ao tocar num posto com turno aberto, a sessão retoma esse turno direto (mesmo monitor, sem novo prompt de nome) — cobre o caso de app fechado/minimizado no meio do turno. Não existe "roubar" o posto de outra pessoa nesta spec.
- **"Entrar como administrador"** entra no app exatamente como ele é hoje (catálogo completo, todas as locações, todas as telas atuais inalteradas) e ganha um ponto de entrada novo pro Painel administrativo (3d) — reaproveita o `HomeShell`/`AppShellCubit` existentes, sem tela nova de "modo admin".
- **Modo monitor troca o `HomeShell` inteiro** por uma tela única nova (3b), escopada a um `toyId`: lista as locações ativas *daquele* brinquedo (reaproveita `ActiveRentalsCubit`/dado do `RentalRepository`, filtrado), botão "Colocar criança" abre o fluxo de nova locação já existente com o brinquedo pré-travado (sem seletor de brinquedo), rodapé mostra o bruto do turno atual. Sem tabs, sem catálogo, sem relatório — mesmo racional do mockup ("o posto é a cama elástica, então o app inteiro é ela").
- **Fechamento de turno (3c):** esperado por forma de pagamento = soma de `price` das locações com `finishedByMonitorName` = monitor da sessão, `toyId` do posto, `endedAt` dentro de `[turno.openedAt, agora]`, agrupado por `paymentMethod`. Só "Dinheiro" pede contagem manual (`countedCash`); diferença = `countedCash - esperadoDinheiro`. Confirmar grava `closedAt`/`countedCash` no `Turno` e volta pra 3a com o posto livre de novo.
- **Painel administrativo (3d):** cards de total faturado hoje (todos os postos) + tabela "por posto e monitor" (uma linha por `Turno` de hoje — aberto ou fechado — com contagem de locações, bruto, status: "aberto" / "fechado" / "diferença de R$X" se `countedCash` divergir) + trilha de lançamentos somente-leitura (últimos eventos de criar/encerrar locação, mais recente primeiro, com autor e horário) em vez das 4 linhas de exemplo do mockup — dado real do dia.

## Cenários de usuário

1. Dado o app recém-aberto, quando a pessoa toca no posto "Cama elástica" (livre) e digita "Gustavo", então entra direto na tela do posto (3b) vendo só as locações ativas da cama elástica.
2. Dado um posto já com turno aberto (ex.: cama elástica, Gustavo), quando outra pessoa abre o app e toca nesse mesmo posto, então entra retomando o turno de Gustavo (mesmo nome, sem novo prompt) — não cria um segundo turno pro mesmo brinquedo.
3. Dado o monitor no posto da cama elástica, quando ele toca "Colocar criança", então o fluxo de nova locação abre com a cama elástica já selecionada, sem precisar escolher o brinquedo.
4. Dado o monitor com locações pagas no turno (2 Pix, 1 dinheiro), quando ele encerra o turno e digita o dinheiro contado, então vê o esperado por forma de pagamento e a diferença calculada (verde se bate, colorida se falta/sobra) antes de confirmar.
5. Dado um turno fechado com diferença de caixa, quando o administrador abre o painel (3d), então vê essa linha com o valor exato da diferença, não escondida.
6. Dado nenhuma locação ainda hoje, quando o administrador abre o painel, então vê total zerado e trilha vazia (sem erro, sem placeholder quebrado).
7. Dado um turno aberto num posto, quando outro monitor tenta abrir um turno **novo** nesse mesmo posto sem antes fechar o existente, então isso não é possível pela UI (tocar no posto ocupado retoma o turno existente, cenário 2 — nunca cria um segundo turno concorrente pro mesmo `toyId`).

## Critérios de aceite

- [x] `lib/domain/models/turno.dart`: modelo `Turno` (`id`, `toyId`, `monitorName`, `openedAt`, `closedAt`, `countedCash`), imutável nos campos fixos, mutável só onde o fluxo de fechar precisa (mesmo padrão de `Rental`).
- [x] `Rental` ganha `createdByMonitorName`/`finishedByMonitorName` (`String?`), migração de schema aditiva no `sqflite` sem quebrar dado existente (`flutter test` da suíte de persistência continua verde).
- [x] `lib/data/services/turno_local_service.dart` + `lib/data/repositories/turno_repository.dart` — Repository é fonte única de verdade de `Turno`, mesmo padrão de `ToyRepository`/`RentalRepository`; impede 2 turnos abertos pro mesmo `toyId`.
- [x] `lib/ui/features/posto/` novo: `PostoSessionCubit` (sessão atual: nenhum posto / monitor num posto / administrador) provido na raiz do app; `main.dart`/`SonhoDeCriancaApp` decide entre tela de abrir posto (3a), tela de posto do monitor (3b) ou `HomeShell` atual (administrador) a partir desse estado.
- [x] View 3a: lista de postos (um por `Toy`) mostrando livre/ocupado (com nome de quem está) + campo de nome + botão entrar + "Entrar como administrador".
- [x] View 3b: locações ativas do `toyId` do posto (reusa dado de `ActiveRentalsCubit`), "Colocar criança" abre nova locação com brinquedo pré-travado, rodapé com bruto do turno, ação de encerrar turno leva a 3c.
- [x] View 3c: esperado por forma de pagamento (Pix/Cartão/Dinheiro) do turno atual, campo de dinheiro contado, diferença calculada e colorida, confirmar fecha o `Turno` e volta pra 3a.
- [x] View 3d (painel administrativo): acessível a partir do modo administrador (novo ponto de entrada no `HomeShell`/nav existente); total faturado hoje, tabela por posto/monitor (turnos de hoje, status, diferença se houver), trilha somente-leitura dos lançamentos reais do dia (criar/encerrar locação).
- [x] `flutter analyze` limpo.
- [x] Teste novo em `test/posto_monitor_painel_test.dart` cobrindo pelo menos: abrir posto livre cria turno e trava o brinquedo na view 3b; tocar posto ocupado retoma o mesmo turno (não duplica); fechamento de turno calcula esperado/diferença corretamente; painel soma faturamento e lista turnos de hoje.

## Requisitos não-funcionais

- Nenhum dado novo sai do aparelho — tudo em SQLite local, mesmo baseline de segurança já documentado (`specs/002-seguranca-dados`); nome de monitor não é dado sensível (é só um rótulo de turno, sem cadastro).
- Migração de schema do `sqflite` é aditiva (novas colunas nuláveis / tabela nova) — banco de quem já usa o app hoje continua abrindo sem perda de dado.

## Dúvidas em aberto

Nenhuma bloqueante — decisões acima cobrem o necessário pro `plan.md`. Revisar com o dono do produto antes de `Approved`.
