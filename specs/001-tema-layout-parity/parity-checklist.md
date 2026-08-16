# Checklist de paridade visual

Capturado via `flutter build web --release` numa cópia isolada (não afeta o repo) + Playwright/Edge headless, viewport 412×915 (referência mobile). Evidência em [evidence/](evidence/). Sem acesso ao `.dc.html` original nesta sessão (ver `spec.md`) — veredito é sobre **consistência interna** (tokens/componentes usados igual em todo lugar), não comparação byte-a-byte contra o design source.

| Tela/componente | Evidência | Veredito | Notas |
|---|---|---|---|
| Painel do dia | [painel-do-dia.png](evidence/painel-do-dia.png) | OK | gradiente do header, `FloatingConfetti` sobre o total, cards "Agora"/"Disponíveis" com tint `accent2`/`yellow`, `PrintStrip` visível no topo. |
| Em andamento | [em-andamento.png](evidence/em-andamento.png) | OK | 3 cards com `toy.ink.tint` correto por brinquedo, `StripedProgress` com cor por faixa (verde/âmbar), contador `+MM:SS` em overtime no card do Pula-Pula. |
| Brinquedos (catálogo) | [brinquedos.png](evidence/brinquedos.png) | OK | grid 2 colunas, tag "1 livre" com `toy.ink.fg`, botão de remover (×) visível, campos de preço/minutos inline. |
| Faturamento | [faturamento.png](evidence/faturamento.png) | OK | seletor Hoje/14 dias/Tudo, barras de forma de pagamento coloridas por `accent`/`accent2`/`processYellow`, breakdown por brinquedo com dot `toy.ink.dot`, histórico consistente. |
| Sheet "Nova locação" | [nova-locacao-sheet.png](evidence/nova-locacao-sheet.png) | OK | presets de minuto, dropdown de brinquedo, botão "Iniciar locação" desabilitado sem nome — confere com `_valid`/validação do form. |
| Sheet "Novo brinquedo" | [novo-brinquedo-sheet.png](evidence/novo-brinquedo-sheet.png) | OK | grade de ícones com seleção destacada (borda `accent`), seletor de cor Ciano/Magenta/Amarelo com o mesmo par tint/fg do `ToyInk`. |
| Dialog "Finalizar locação" | [finalizar-locacao-dialog.png](evidence/finalizar-locacao-dialog.png) | Gap corrigido | **Confirmado como bug real** (não artefato de captura): título "Finalizar locação" renderizava vermelho/sublinhado. Causa: `showEndRentalDialog` (`modal_launchers.dart:31`) usa `showGeneralDialog`, que — ao contrário de `showModalBottomSheet` (usado por `NewRentalSheet`/`AddToySheet`) — não envolve o conteúdo num `Material` ancestor; `Text` solto sem essa ancestralidade cai no fallback de estilo do engine. Botões escapavam porque `ElevatedButton`/`OutlinedButton` carregam `Material` próprio. Corrigido envolvendo `EndRentalDialog` num `Material(type: MaterialType.transparency)` em `end_rental_dialog.dart`. Evidência atualizada após a correção — título agora renderiza igual às outras telas. `flutter analyze` limpo, `flutter test` passando antes e depois. |

## Consistência de token (auditoria cruzada com `design-tokens.md`)

- Toda cor usada nas 7 capturas veio de `AppColors`/`ToyInk` — nenhum hex solto visível.
- Todo botão primário usa `accent` (`#0088B0`), toda ação de destaque (FAB, "Confirmar") usa `accent2` (`#D6006C`) ou `accent`, consistente entre telas.
- Raio de borda pequeno (inputs, tags, botões) e raio grande (topo de sheet) seguem a família documentada em `design-tokens.md`.
- 1 `Gap` encontrado e corrigido: `EndRentalDialog` sem `Material` ancestor (ver linha do dialog acima) — único ponto onde `lib/` foi tocado nesta spec, tratado como bugfix simples (não precisou de spec própria: é mecânico, sem mudança de comportamento/escopo, só a correção de um estilo que já devia estar assim).

## Conclusão

7 de 7 telas/componentes fecham `OK`. O único `Gap` (título do dialog "Finalizar locação" sem `Material` ancestor) foi corrigido em `end_rental_dialog.dart`, verificado com `flutter analyze` + `flutter test` antes/depois e reconfirmado visualmente com novo screenshot pós-fix.
