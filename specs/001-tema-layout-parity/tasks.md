# Tasks: Tema e paridade de layout com o design source

Referência: [spec.md](spec.md) + [plan.md](plan.md) nesta mesma pasta.

- [x] T1 — escrever `design-tokens.md` (cor, tipografia, espaçamento, raio, motion, com `arquivo:linha`)
- [x] T2 — escrever `component-inventory.md` (todo widget reutilizável, onde é usado)
- [x] T3 — rodar app (build web release em cópia isolada + Playwright/Edge headless, repo real intocado), capturar as 4 abas + 3 modais/sheets — evidência em `evidence/`
- [x] T4 — preencher `parity-checklist.md` com veredito por tela — 6/7 `OK`, 1 `Não verificável nesta sessão` (cor do título do dialog "Finalizar locação", isolado, sem erro de console/rede, precisa de confirmação num device real)
- [x] T5 — nenhum `Gap` de inconsistência interna encontrado — nada a corrigir
- [x] T6 — `flutter analyze`: limpo. `flutter test` (`test/widget_test.dart`): passou. `integration_test/app_test.dart` requer device/emulador conectado (não roda em `flutter test` puro) — não executado nesta sessão, sem device attachado; nenhum arquivo de `lib/`/`test/` foi tocado por esta spec, então não há risco de regressão introduzida por ela.

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
