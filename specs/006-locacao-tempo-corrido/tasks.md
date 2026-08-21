# Tasks: Locação em tempo corrido

Referência: [spec.md](spec.md) + [plan.md](plan.md).

- [x] T1 — `Rental.durationMin` nullable, `price` mutável, `isOpenEnded` getter
- [x] T2 — `AppState`: `RentalDraft.openEnded`, `ratePerMinute`, `computeFinalPrice`
- [x] T3 — `submitNew()` cria locação tempo corrido (`durationMin: null`, `price: 0`)
- [x] T4 — `confirmEnd()` calcula preço final via `computeFinalPrice` antes de `finish()`
- [x] T5 — `NewRentalSheet`: toggle tempo fixo/corrido, oculta campos irrelevantes, mostra taxa/min
- [x] T6 — `ActiveTab`/`_ActiveCard`: variante crescente (`_fmtElapsed`) sem `StripedProgress`/overtime
- [x] T7 — `EndRentalDialog`: resumo usa `computeFinalPrice` (valor certo antes de confirmar)
- [x] T8 — teste unitário de `computeFinalPrice` (22min = R$11,00, caso fracionário 22min37s = R$11,31, tempo fixo inalterado) — `test/open_ended_rental_test.dart`
- [x] T9 — teste de widget: criar/finalizar tempo corrido (valor calculado bate), criar/cancelar (sem cobrança), toggle da sheet
- [x] T10 — `flutter analyze` limpo, `flutter test` (13 testes) passando, evidência visual em `evidence/nova-locacao-toggle.png`

## Amendment (2026-08-21): taxa por minuto customizável

**Pedido do usuário:** taxa derivada de `preço/blockMin` do brinquedo era fixa, sem opção de ajustar — usuário não sabia de antemão se essa taxa batia com o que queria cobrar por tempo corrido, pediu pra ficar editável.

**Mudança:**
- `Rental.ratePerMinute` (novo campo, `double?`) — capturado **uma vez, na criação**, não mais recalculado do catálogo a cada chamada de `computeFinalPrice`. Corrige de brinde um bug lateral: antes, editar o preço/bloco do brinquedo no catálogo com uma locação tempo corrido já em andamento mudava retroativamente a taxa dela — agora a locação mantém a taxa com que nasceu, mesmo espírito do fix do congelamento de preço do Pix.
- `RentalDraft.customRatePerMinute` (`double?`) — `null` usa a sugestão derivada do catálogo (`AppState.ratePerMinute(toy)`); setado pelo operador via `AppState.setDraftCustomRate`, sobrescreve. Resetado sempre que o brinquedo do draft muda (`setDraftToy`) — taxa digitada pra um brinquedo não vaza pro próximo.
- `NewRentalSheet`: campo de texto editável no lugar da caixa somente-leitura, pré-preenchido com a sugestão, com a sugestão do catálogo ainda visível como dica abaixo.
- `computeFinalPrice`: usa `r.ratePerMinute ?? ratePerMinute(toyById(r.toyId))` — fallback pro cálculo antigo só pra dado antigo/teste que não setou o campo, nunca em locação criada depois desta mudança.

**Testes novos** (`test/open_ended_rental_test.dart`, grupo "customizable tempo-corrido rate"):
- taxa custom sobrescreve a do catálogo e é o que efetivamente cobra;
- sem override, cai pra taxa padrão do catálogo (comportamento antigo preservado);
- trocar de brinquedo limpa a taxa custom digitada.

30 testes no total, `flutter analyze` limpo. Evidência visual desta rodada específica não capturada (falha de coordenada no script de screenshot, não do app) — comportamento coberto com confiança pelos testes automatizados acima.

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`. Se algo quebrar no meio, parar ali (regra de não-quebra), não emendar.
