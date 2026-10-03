# Spec: Turno via backend — entrega pelo monitor, fechamento pelo administrador

Status: Draft
Criado: 2026-10-03

Contraparte Flutter da [backend#003 — Turno do posto + trilha + avisos do admin](../../../sonho-de-crianca-backend/specs/003-turno-posto-trilha/spec.md), já em produção (backend PR #9). Revisa o fluxo de turno da [023-posto-monitor-painel](../023-posto-monitor-painel/spec.md) e mantém as decisões de login da [026](../026-rental-via-backend/spec.md)/[027](../027-login-admin-sessao/spec.md): monitor sem conta, nome livre; o tablet usa a sessão salva do administrador.

## Problema

- **`Turno` só existe no SQLite do tablet.** Outro aparelho não vê quem está em cada posto, e a dona não vê a conferência de caixa de longe. O painel (3d) e a seção de caixa do relatório ([028](../028-relatorio-dono-whatsapp/spec.md)) só enxergam os turnos daquele aparelho.
- **O nome do monitor some.** `createdByMonitorName`/`finishedByMonitorName` só existem em memória: ao recarregar `GET /api/rentals`, voltam `null`. Isso quebra o caixa do turno (que filtra por quem recebeu) e o "por monitor" do relatório depois de qualquer recarga.
- **O monitor fecha o próprio caixa.** Hoje quem confere o dinheiro é quem está entregando. A backend#003 separou isso: o monitor **entrega** (informa quanto tem na mão), e só o **administrador fecha**, depois de conferir.

## Objetivo

O turno de cada posto passa a morar no backend: abrir, entregar e fechar são chamadas à API, e as locações feitas no posto levam o `shiftId`. O monitor continua só digitando o nome. O administrador vê os turnos entregues, fecha cada um e recebe avisos do que aconteceu desde a última vez que entrou.

## Fora de escopo

- **Trilha de lançamentos e painel do dia via backend** (`/api/audit`, `/api/dashboard`). O painel (3d) continua calculando localmente, só que agora a partir de turnos e locações vindos do backend. A troca pra agregação no servidor e a trilha completa (cancelamento, mudança de preço, cortesia) ficam pra spec própria.
- **Cortesia** (`courtesyReason`) e **motivo de cancelamento** (`reason`): o backend aceita, mas a UI pra informar fica pra mesma spec da trilha.
- **Migrar turnos do SQLite.** Mesma linha da 022/024/025/026: depois de atualizar, vale o que nasce no backend. Turno aberto localmente na hora da atualização é abandonado. O monitor abre de novo.
- **Funcionar sem internet.** Igual à 026: abrir, entregar e fechar turno exigem rede. Sem rede, aviso claro, e nada é gravado.
- **Push com o app fechado.** Os avisos aparecem ao entrar no modo administrador ou ao atualizar a tela.

## Decisões propostas (confirmar na aprovação)

1. **`TurnoRepository` passa a falar HTTP** (`GET/POST /api/shifts`, `PATCH .../handover`, `PATCH .../close`), com a sessão salva do administrador, como `RentalRepository` na 026. Tabela de turno do SQLite deixa de ser usada.
2. **`Turno` ganha os campos do servidor**: `number`, `status` (`open`/`handed_over`/`closed`), `handedOverAt`, totais (`rentalsCount`, `gross`, `byPayment`) e `cashDifference`. Os totais e a diferença **vêm do servidor**, não são recalculados no app.
3. **Abrir posto (3a)**: tocar num posto livre e digitar o nome chama `POST /api/shifts`. Posto ocupado em **qualquer** aparelho aparece ocupado (lista recarrega ao abrir a tela e ao voltar pra ela). Dois tablets ao mesmo tempo: quem perde recebe `409` e vê "Esse posto acabou de ser aberto por outra pessoa", e a lista atualiza.
4. **Locação no posto manda `shiftId`** em criar, estender, cancelar e finalizar. O nome do monitor passa a vir **do servidor** na resposta, e não é mais preenchido localmente. Fora do posto (modo administrador), nada muda: sem `shiftId`, nomes `null` ("Administrador" no relatório).
5. **"Encerrar turno" vira "Entregar caixa" (3c)**: o monitor vê o esperado por forma de pagamento (do servidor, `GET /api/shifts/:id`), digita o dinheiro contado e confirma → `PATCH .../handover`. A diferença mostrada depois da entrega é a `cashDifference` do servidor. O posto fica livre pro próximo monitor.
6. **Fechar turno é do administrador**: nova seção "Turnos pra fechar" no painel administrativo, listando `?status=handed_over` (monitor, posto, nº, contado, diferença destacada). "Fechar" chama `PATCH .../close`. Se o backend responder `403` (login de mais de 15 min), o app abre o login e, depois de entrar, tenta de novo sozinho.
7. **Avisos ao entrar como administrador**: `GET /api/notifications` mostra "Gustavo abriu Cama elástica", "Ana entregou Carrinho, faltou R$ 10,00" e um contador de turnos pra fechar. "Marcar como visto" chama `POST /api/notifications/seen`. O contador de turnos pra fechar só zera quando todos forem fechados.
8. **Relatório (028) e painel (3d) leem turnos do backend.** A seção de caixa do relatório passa a usar `cashDifference` do servidor, e não `ComputeTurnoCash`. Assim o número é o mesmo em qualquer aparelho. Turno entra no período pela data de entrega (`handedOverAt`), porque é quando o caixa é contado.
9. **Monitor entregou e o posto abre de novo com o mesmo nome?** Pode: turno `handed_over` não bloqueia o posto (regra do backend).

## Cenários de usuário

1. Dado a Cama elástica livre, quando o tablet A abre turno com "Gustavo", então o tablet B, ao abrir a lista de postos, vê a Cama elástica ocupada por Gustavo.
2. Dado dois tablets abrindo turno na Cama elástica ao mesmo tempo, então um entra no posto e o outro vê o aviso de que o posto acabou de ser aberto, sem duplicar turno.
3. Dado Gustavo no posto, quando ele cria e finaliza uma locação, então depois de recarregar o app (ou em outro aparelho) a locação continua mostrando Gustavo como quem criou e quem recebeu.
4. Dado Gustavo com R$ 80 esperado em dinheiro, quando ele entrega o caixa informando R$ 70, então vê diferença de -R$ 10,00, o posto fica livre, e a Cama elástica aparece livre nos outros aparelhos.
5. Dado um turno entregue, quando o administrador entra no app, então vê o aviso da entrega com a falta de R$ 10,00 e "1 turno pra fechar".
6. Dado o administrador logado há mais de 15 min, quando toca "Fechar" num turno entregue, então o app pede login; depois de entrar, o turno é fechado sem ele tocar de novo.
7. Dado o administrador fechou o turno, então ele sai de "Turnos pra fechar", e o relatório da semana mostra a diferença de -R$ 10,00 igual em qualquer aparelho.
8. Dado o tablet sem internet, quando o monitor tenta abrir posto ou entregar caixa, então vê aviso de sem conexão e nada muda (nem local, nem no servidor).
9. Dado o administrador cria uma locação fora de um posto, então ela é gravada sem `shiftId` e aparece como "Administrador" no relatório, como hoje.

## Critérios de aceite

- [ ] `TurnoRepository` via HTTP (listar, abrir, entregar, fechar); SQLite de turno sem uso; `409` ao abrir vira aviso, não erro genérico.
- [ ] `Turno` com `number`, `status`, `handedOverAt`, `rentalsCount`, `gross`, `byPayment`, `countedCash`, `cashDifference` vindos do servidor.
- [ ] Locações feitas no posto mandam `shiftId` em criar/estender/cancelar/finalizar; nomes do monitor vêm da resposta do servidor e sobrevivem a recarga.
- [ ] Tela 3c vira "Entregar caixa": esperado do servidor, contado digitado, `handover`, diferença do servidor.
- [ ] Painel administrativo com "Turnos pra fechar" (`?status=handed_over`) e ação "Fechar"; `403` abre login e refaz o fechamento.
- [ ] Avisos ao entrar como administrador (`/api/notifications`), com "marcar como visto" e contador de pendentes.
- [ ] Relatório (028) e painel (3d) usam turnos do backend; diferença de caixa = `cashDifference` do servidor.
- [ ] Sem rede: aviso claro em abrir/entregar/fechar, sem estado inconsistente.
- [ ] `flutter analyze` limpo; testes com backend fake cobrindo cenários 1–9; suíte existente verde (ajustada só onde o fluxo mudou de "fechar" pra "entregar").

## Requisitos não-funcionais

- Zero-breakage no backend: nenhuma rota nova no servidor, só consumo da backend#003.
- Nenhum dado novo de criança/responsável sai do aparelho além do que a 026 já manda. `monitorName` é um rótulo, não dado sensível (023).
- Lista de postos e de turnos pra fechar não pode travar a tela sem rede: mostra o último estado conhecido com aviso.

## Dúvidas em aberto

1. **Recorte**: esta spec inclui avisos (decisão 7) e "Turnos pra fechar" (6). Trilha, painel agregado no servidor e cortesia ficam pra spec seguinte. Concorda com esse corte, ou prefere puxar painel/trilha pra cá também?
2. **Monitor vê a diferença ao entregar?** Proposta: sim, como hoje. Alternativa: esconder do monitor e mostrar só pro admin (evita o monitor "ajustar" a contagem depois de ver a diferença).
3. **Turno local aberto na hora da atualização**: proposta é abandonar (decisão "fora de escopo"). Alternativa: na primeira abertura depois da atualização, avisar "havia um turno aberto neste aparelho, abra de novo".
