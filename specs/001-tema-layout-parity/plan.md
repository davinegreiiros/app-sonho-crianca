# Plan: Tema e paridade de layout com o design source

Referência: [spec.md](spec.md) nesta mesma pasta.

## Abordagem técnica

Trabalho é 100% documentação + auditoria, sem mudar comportamento — não há refator de widget nesta spec (só se um `Gap` for achado, e mesmo assim vira task separada, sob a regra de não-quebra).

1. Extrair todo token hoje espalhado em `lib/theme/` e `lib/widgets/animations/` pra `design-tokens.md`, citando `arquivo:linha`.
2. Catalogar todo componente reutilizável de `lib/widgets/` (inclui `animations/`) em `component-inventory.md`: o que é, onde é usado, quais props variam.
3. Rodar o app via skill `run`, capturar as 4 abas (Painel, Em andamento, Brinquedos, Faturamento) + os dois modais (Nova locação, Finalizar locação) + a sheet de novo brinquedo.
4. Preencher checklist de paridade em `parity-checklist.md` comparando o que dá pra verificar (consistência interna do app: mesma cor/raio/motion reaproveitado em todo lugar que deveria) — sem o `.dc.html` aberto nesta sessão, o veredito "bate com o design original" fica `Não verificável nesta sessão` onde não dá pra confirmar contra a fonte, nunca forçado pra `OK`.
5. Qualquer inconsistência interna achada (ex: um raio de borda fora do padrão, uma cor hardcoded fora de `AppColors`) vira item `Gap` com task de correção própria em `tasks.md` — não corrigido inline durante a auditoria.

## Arquivos afetados

- `specs/001-tema-layout-parity/design-tokens.md` — novo.
- `specs/001-tema-layout-parity/component-inventory.md` — novo.
- `specs/001-tema-layout-parity/parity-checklist.md` — novo.
- Nenhum arquivo em `lib/` é tocado por esta spec, a menos que um `Gap` vire task de correção explícita (listada separadamente em `tasks.md`, cada uma com seu próprio `flutter analyze` + teste antes de fechar).

## Modelo de dados / estado

N/A — spec não mexe em `Toy`/`Rental`/`AppState`.

## Riscos / dependências

- Sem o `.dc.html` aberto, corro risco de documentar "o que o código já faz" em vez de "o que o design pede" — mitigado marcando explicitamente `Não verificável nesta sessão` em vez de assumir OK.
- Nenhuma dependência de outra spec.

## Alternativas consideradas

- Pular a documentação e ir direto pras specs de feature: descartado — 003/004/005/006 todas dependem de reusar token/componente existente sem inventar; sem isso documentado, cada uma decide sozinha e diverge.
