# Spec: Revisão de Design v3 — ícones de categoria, canhoto, Pix, Configurações, tempo corrido

Status: Implemented
Criado: 2026-08-21

## Problema

Design fonte `Revisao de Design v3.dc.html` (projeto Claude Design `c7934e05-8a2f-4e04-97da-98802b6c3a40`) revisa 5 pontos específicos do app já implementado, com id de artboard 1a–1e:

- **1a** — canhoto de disponibilidade: falta textura de retícula (halftone) dentro do canhoto livre; "em uso" deveria ficar mais claramente "destacado" (contorno 45%).
- **1b** — categoria do brinquedo (`ToyCategory`) hoje é só texto (pill no card, chip em "Novo brinquedo") — sem ícone. Design pede ícone Phosphor duotone por categoria, uma tinta fixa por categoria (não a tinta CMY do brinquedo).
- **1c** — dialog de cobrança Pix (`PixQrSheet`) é uma caixa genérica — design pede visual de "cupom de caixa" (serrilha, faixa CMY, nº de documento), estado "aguardando confirmação" e botão "Trocar forma" pra voltar à escolha de método sem fechar o fluxo.
- **1d** — "Configurações do negócio" só existe como bottom sheet; design pede tela cheia (destino de navegação, não formulário de fluxo), com prévia viva do QR ao lado da chave Pix.
- **1e** — card de locação em tempo corrido não tem indicador visual de progresso (nenhuma barra hoje) nem reforça o modo "sem fim"; CTA "Finalizar" não deixa claro que a ação é parar a contagem.

## Objetivo

As 5 telas/componentes acima batem visualmente com os artboards 1a–1e do design v3, reusando os tokens já documentados em `specs/001-tema-layout-parity/` — sem introduzir cor/raio/fonte novos fora do que os artboards mostram.

## Fora de escopo

- Qualquer artboard ou tela não coberta pelos ids 1a–1e.
- Polling real de confirmação de pagamento Pix (webhook/API do banco) — o app continua 100% local e offline (baseline de segurança da constitution); "aguardando confirmação" é só estado visual até o operador confirmar manualmente.
- Substituir o ícone de launcher do app (`assets/icon/*`) — os ícones novos desta spec são só os de categoria (1b), não o ícone do app.
- QR com os 3 "olhos" em cores diferentes (ciano/magenta/amarelo) — `qr_flutter` só pinta os 3 olhos com uma cor única; o QR fica monocromático na tinta de destaque. Documentado como desvio intencional.

## Decisões (assumidas pelo dono do produto ao pedir a implementação direta a partir do link do design)

- Ícones de categoria: adicionados como assets SVG (paths Phosphor extraídos 1:1 do `.dc.html`) + dependência nova `flutter_svg` — não existe pacote de ícone vetorial no projeto hoje; alternativa (desenhar cada ícone à mão em `CustomPainter`) foi descartada por ser mais frágil pra manter fiel ao design.
- Nº de documento do cupom Pix = id da locação, saneado pra alfanumérico maiúsculo — também passa a ser usado como `txid` real do payload EMV (`buildPixPayload`), que hoje é sempre `***`.
- "Trocar forma" no cupom Pix volta ao passo de escolha de método dentro do mesmo dialog (não fecha o fluxo de finalizar locação).
- Configurações vira `Navigator.push` (tela cheia) a partir do mesmo ícone de engrenagem e do mesmo hint quando Pix é escolhido sem configuração — não é uma rota nomeada nova no `MaterialApp` (app não usa rota nomeada em lugar nenhum hoje).

## Cenários de usuário

1. Dado o catálogo, quando o usuário olha o pill de categoria de um card ou os chips em "Novo brinquedo", então vê o ícone Phosphor duotone da categoria na tinta fixa correspondente (amarelo=Elétrico, magenta=Insuflável/Rádio-controle, ciano=Passeio/Aquático, neutro=Outro).
2. Dado um brinquedo com unidades livres, quando o usuário olha os canhotos no card, então o canhoto livre mostra a retícula de pontos e o em uso aparece com contorno a 45% (sem preenchimento).
3. Dado o operador finalizando uma locação por Pix, quando o QR aparece, então o dialog tem visual de cupom (serrilha + faixa CMY + nº de documento) e mostra "Aguardando confirmação" pulsando; se ele tocar "Trocar forma", volta pra escolha de método de pagamento sem perder a locação selecionada.
4. Dado o operador tocando a engrenagem no header, quando a tela abre, então é uma tela cheia com botão "Painel" pra voltar, não um bottom sheet — e o campo de chave Pix mostra uma prévia miniatura do QR ao lado.
5. Dado um card de locação em tempo corrido, quando o usuário olha o card, então vê o trilho tracejado "sem fim", o bloco "Estimado agora" com valor e minutos, e o botão diz "Parar e cobrar" em vez de "Finalizar".

## Critérios de aceite

- [x] `ToyCategory` tem ícone (asset SVG) e cor de tinta fixa por categoria, usados no pill do card (`catalog_tab.dart`) e nos chips de "Novo brinquedo" (`add_toy_sheet.dart`).
- [x] `_TicketStub` (canhoto) pinta retícula de pontos quando livre; "em uso" usa só contorno a 45% de opacidade, sem preenchimento.
- [x] `PixQrSheet` tem faixa CMY + perfuração decorativa no topo, nº de documento (= id da locação saneado), estado "Aguardando confirmação" pulsando, e botão secundário "Trocar forma" que volta ao passo de escolha de pagamento. (Serrilha implementada como fileira de pontos decorativa no fluxo, não como clip real do card — ver plan.md "Riscos".)
- [x] `buildPixPayload` recebe `txid` real (não mais fixo `***`) vindo do id da locação.
- [x] Configurações do negócio abre como tela cheia (`Navigator.push`), com botão "Painel" de voltar e prévia miniatura do QR ao lado do campo de chave Pix; os dois pontos de entrada existentes (engrenagem, hint do Pix não configurado) continuam funcionando.
- [x] Card de locação em tempo corrido mostra trilho tracejado "sem fim" (substituindo a ausência de barra de progresso), bloco "Estimado agora", e botão "Parar e cobrar" (só pra tempo corrido — locação de duração fixa continua "Finalizar").
- [x] `flutter analyze` limpo.
- [x] Teste novo/alterado em `test/design_v3_test.dart` cobrindo: ícone de categoria aparece pro tipo certo, CTA "Parar e cobrar" em tempo corrido vs "Finalizar" em fixo, Configurações abre como tela cheia. Canhoto livre vs em uso já coberto (comportamento `free` inalterado) por `test/catalog_tickets_test.dart`.

## Requisitos não-funcionais

- Nenhuma permissão nova, nenhum dado saindo do aparelho (baseline `specs/002-seguranca-dados/spec.md` continua valendo — "aguardando confirmação" é decorativo, não implica rede).
- Assets SVG novos ficam em `assets/icons/category/`, registrados no `pubspec.yaml`.

## Dúvidas em aberto

Nenhuma — decisões de implementação registradas acima; retomar aqui só se algo virar bloqueio durante o `plan.md`/implementação.
