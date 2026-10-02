# Spec: Catálogo via backend + sessão de dispositivo

Status: Implemented
Criado: 2026-10-01

> **Sessão de dispositivo removida pela [027-login-admin-sessao](../027-login-admin-sessao/spec.md)** — leitura passa a usar a sessão do administrador; `secrets.json`/`DEVICE_OPERATOR_*` não existem mais.

Segunda fatia da árvore aberta pela [022-backend-sync-fundacao](../022-backend-sync-fundacao/spec.md) — depois da [024-sync-backend-fundacao](../024-sync-backend-fundacao/spec.md) (login de operador + `BusinessSettings`). Resolve uma colisão de arquitetura achada ao planejar esta fatia (ver "Decisão — sessão de dispositivo" abaixo) antes de migrar `Toy`.

## Problema

`Toy` ainda é só local (SQLite, spec 020) — dois aparelhos não veem o mesmo catálogo. Migrar pro padrão HTTP da 024 (toda rota exige operador logado) esbarra num problema que a 024 não tinha: o modo posto ([023-posto-monitor-painel](../023-posto-monitor-painel/spec.md), "Quem é você hoje", sem conta) **lê o catálogo o tempo todo** pra montar a lista de postos — `BusinessSettings` só era lido em modo administrador, `Toy` não. Se toda leitura de catálogo passasse a exigir login, o posto inteiro para de funcionar sem conta, contradizendo a decisão explícita da 023.

## Decisão — sessão de dispositivo (resolve a colisão acima)

Duas sessões distintas, não uma:

1. **Sessão de dispositivo** — login automático e silencioso no boot do app, com um operador dedicado (`device`, seedado uma vez via `npm run seed:operator` no repo backend, credencial fixa embutida no app — não digitada por humano). Usada só pra **ler** o catálogo (`GET /api/toys`). Vale pra todo mundo, posto ou admin, sem pedir nada de ninguém.
2. **Sessão de operador real** — login explícito (já existe desde a 024: `AuthRepository.login`, `LoginView`). Continua exigida antes de qualquer **escrita** sensível: `BusinessSettings` (já é assim) e, a partir desta spec, **editar o catálogo** (criar/editar/remover brinquedo — ação de administrador, nunca alcançável pelo posto hoje, ver `PostoSessionCubit`).

Por que não uma sessão só: a credencial de dispositivo fica embutida no app (quem decompilar o APK a vê) — por isso ela só pode **ler**, nunca escrever nada que custe dinheiro ou mude o catálogo. Separar as duas mantém o motivo original da 022 (saber quem fez cada ação que importa) intacto, e ainda deixa o posto funcionar sem conta, como a 023 já decidiu.

**Alcance desta fatia**: só `Toy`. `Rental` (criar/estender/cancelar via sessão de dispositivo, `finish` exigindo sessão real) é a spec seguinte, que reaproveita a sessão de dispositivo construída aqui — ver "Fora de escopo".

## Objetivo

`ToyRepository` lê/escreve no backend em vez de SQLite. Leitura (`load`/refresh) usa a sessão de dispositivo, silenciosa, sem pedir login a ninguém. Escrita (criar/editar/remover brinquedo) exige sessão de operador real — mesma guarda de login que `BusinessSettingsView` já usa, reaproveitada.

## Fora de escopo

- **`RentalRepository` via HTTP** — spec seguinte. Reaproveita a sessão de dispositivo (criar/estender/cancelar) + sessão real (`finish`, onde dinheiro muda de mão) — é lá que `Turno.monitorName` (posto) encontra `Operator` (login) de verdade, não aqui, porque `Toy` nunca passou por essa colisão (catálogo não tem "quem fez").
- **Migração de dado local existente** — mesma decisão da 022/024: primeiro boot com o catálogo do backend é o que vale; não empurra o SQLite local pra lá.
- **Permissão diferenciada por papel** (ex.: só "admin" pode editar catálogo) — v1 continua sem isso (022); qualquer operador real logado pode editar, a guarda é só "tem que ser uma pessoa logada", não "tem que ser uma pessoa com papel X".
- **Rotação/gestão da credencial de dispositivo pelo app** — é um valor fixo de configuração (igual `API_BASE_URL`), trocar a senha é operação manual (re-seed + atualizar o app), não uma tela.

## Cenários de usuário

1. Dado o posto abre sem login nenhum (spec 023), quando a tela de seleção de posto monta, então ela mostra a lista de brinquedos vinda do backend — sem pedir conta a ninguém.
2. Dado um brinquedo editado em um aparelho (preço, por exemplo), quando outro aparelho reabre o catálogo, então vê o preço novo.
3. Dado o administrador tenta editar/criar/remover um brinquedo sem sessão de operador real, quando a ação é disparada, então é levado ao login primeiro (mesma UX da 024) — só depois de logado a escrita acontece.
4. Dado a sessão de dispositivo falhar (ex.: sem internet no boot), quando o catálogo tenta carregar, então a UI mostra o que tiver em cache local (não trava, não fica em branco) e tenta de novo depois, sem exigir nenhuma ação do operador.
5. Dado um brinquedo com `Rental` vinculado (ativo ou histórico), quando o administrador tenta remover, então o backend recusa (409, já existe desde a spec 001) e o app mostra o motivo — mesma regra de sempre, agora validada contra o servidor, não só contra dado local.

## Critérios de aceite

- [x] Operador `device` seedado em produção (`npm run seed:operator` no repo backend) — credencial registrada só em configuração do app (não em texto plano commitado — mesma régua de `.env`/segredo da constitution).
- [x] `AuthRepository` ganha a sessão de dispositivo: login automático e silencioso no boot (`main.dart`), token próprio, separado do token de operador real. 401 na sessão de dispositivo tenta relogar uma vez; falha de novo só loga (não trava boot, não aparece pro usuário).
- [x] `ToyRepository.load()`/refresh usa a sessão de dispositivo via `GET /api/toys` — mesma forma pública de hoje (otimista, sem mudar assinatura síncrona de leitura).
- [x] `ToyRepository.addNew`/`updatePrice`/`updateBlockMinutes`/`remove` passam a `Future<...>`, chamando `POST/PATCH/DELETE /api/toys` com a sessão de operador real — sem sessão válida, a mesma guarda de login da `BusinessSettingsView` entra em ação antes.
- [x] `ToyCatalogCubit` repassa o novo formato async. `AppState` (proxy legado) não precisou repassar nada — suas mutações de `Toy` (`addToy`/`updateToyPrice`/`updateToyBlock`/`removeToy`) já não tinham chamador desde as specs 012/015 (`catalog_view.dart`/`add_toy_sheet_view.dart` usam `ToyCatalogCubit`); removidas em vez de convertidas.
- [x] `DELETE` recusado (brinquedo com `Rental`) mostra mensagem de erro clara na UI, não trava nem finge sucesso.
- [x] Teste cobrindo os 5 cenários acima — sessão de dispositivo mockada, nenhum teste bate no backend real.
- [x] `flutter analyze` limpo.

## Requisitos não-funcionais

- Sessão de dispositivo nunca aparece em log/print (mesma régua de token/senha da constitution).
- Falha de rede na leitura do catálogo é sempre silenciosa pro posto (cenário 4) — é o fluxo principal do dia a dia, não pode ficar refém de conectividade.

## Dúvidas em aberto

Nenhuma bloqueante — a decisão de arquitetura (sessão de dispositivo) já foi discutida e aprovada antes deste rascunho. Um ponto a confirmar no `plan.md`, não aqui: exatamente onde a credencial de dispositivo fica guardada no app (ex.: `String.fromEnvironment` tipo `API_BASE_URL`, ou um arquivo de config não commitado) — decisão técnica, não de produto.
