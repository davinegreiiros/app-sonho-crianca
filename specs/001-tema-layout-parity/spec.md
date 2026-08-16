# Spec: Tema e paridade de layout com o design source

Status: Implemented
Criado: 2026-08-15

## Problema

O app foi implementado a partir do design Claude (`Sonho de Crianca App v2.dc.html`, projeto `c7934e05-8a2f-4e04-97da-98802b6c3a40`), portado à mão pra Flutter (`lib/theme/`, `lib/widgets/animations/`). O resultado hoje está bom, mas:

- Não existe um documento único que liste os tokens (cor, tipografia, espaçamento, raio, motion) e diga de onde cada um veio no design original — quem for portar peça nova (specs 003–006) não tem onde consultar, só o código já existente.
- Não existe checklist de paridade tela a tela contra o `.dc.html` — não dá pra afirmar com confiança "está 1:1" sem comparar de novo.
- **Limitação desta sessão:** não tenho acesso ao MCP `claude_design` aqui (roda não-interativo, sem `/design-login`). Não consigo reabrir `Sonho de Crianca App v2.dc.html` nem o bundle `_ds/.../_ds_bundle.js` / `styles.css` diretamente. A auditoria desta spec parte do que já foi portado (comentários no código citam a origem: ex. `lib/theme/app_colors.dart:3`, `end_rental_dialog.dart:11`) + comparação visual via `/run` no app rodando. Se quiser paridade byte-a-byte contra o `.dc.html`, isso precisa rodar numa sessão interativa com `/design-login` feito, ou você exporta/cola aqui o conteúdo dos arquivos do design.

## Objetivo

Um documento de tokens + inventário de componentes vira a fonte única de verdade de design do app, com checklist de paridade preenchido contra o estado atual — e toda spec de feature nova (003, 004, 005, 006) é obrigada a reusar esses tokens/componentes em vez de inventar cor, raio ou espaçamento novo.

## Fora de escopo

- Redesenhar qualquer tela existente ou mudar token de cor/tipografia por preferência estética.
- Implementar as features novas (tickets, QR Pix, notificações, tempo corrido) — isso é das specs 003–006, que apenas *consomem* o resultado desta spec.
- Dark mode (não existe no design original; não inventar).

## Cenários de usuário

1. Dado o app rodando, quando o usuário navega pelas 4 abas (Painel, Em andamento, Brinquedos, Faturamento), então cor, tipografia, espaçamento e motion batem com o que está documentado no tokens doc — sem "quase igual".
2. Dado um dev implementando a spec 003 (tickets no catálogo), quando ele precisa de uma cor/raio/tag pro componente novo, então encontra o token certo no documento desta spec em vez de escolher um valor novo.
3. Dado um componente do design original ainda sem paridade confirmada (ex: motion específico do `_ds_bundle.js` não replicado), então isso aparece como item `Gap` explícito no checklist, não como "ok" por omissão.

## Critérios de aceite

- [ ] `specs/001-tema-layout-parity/design-tokens.md` lista cor, tipografia (família/peso/tamanho), espaçamento, raio e motion em uso hoje, cada um com `arquivo:linha` de origem (`AppColors`, `AppTheme`, `lib/widgets/animations/*`).
- [ ] `specs/001-tema-layout-parity/component-inventory.md` lista todo componente reutilizável em `lib/widgets/` (cards, tags, botões, inputs, bottom sheet, modal, `StripedProgress`, `PrintStrip`, `ToyIcon`, `Bouncy`, `Pressable`, `CascadeController`) com onde é usado hoje.
- [ ] Checklist de paridade por aba (Painel/Em andamento/Brinquedos/Faturamento) preenchido com veredito (`OK` / `Gap` / `Não verificável nesta sessão`) — usar `/run` pra capturar screenshot de cada aba como evidência.
- [ ] Todo item marcado `Gap` vira uma task de correção separada em `tasks.md`, sob a regra de não-quebra da constitution — nunca corrigido "de brinde" dentro de outra spec.
- [ ] `flutter analyze` limpo e suíte atual (`test/widget_test.dart` + `integration_test/app_test.dart`) continua passando sem alteração de comportamento — esta spec é só documentação + eventual correção de gap visual, não deve mudar fluxo.

## Requisitos não-funcionais

- Documento em Markdown dentro da própria pasta da spec (`design-tokens.md`, `component-inventory.md`), não em `CLAUDE.md` nem solto na raiz.

## Dúvidas em aberto

- Confirmar se dá pra rodar `/design-login` + MCP `claude_design` numa sessão interativa pra comparação byte-a-byte, ou se a auditoria visual via `/run` é suficiente.
- Existe algo no `.dc.html` original ainda não portado (ex: alguma tela, estado vazio, microinteração) que você sabe que ficou de fora? Ajuda a priorizar o checklist.
