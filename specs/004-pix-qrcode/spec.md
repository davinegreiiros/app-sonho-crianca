# Spec: QR Code Pix na finalização de locação

Status: Draft
Criado: 2026-08-15
Depende de: [specs/002-seguranca-dados/spec.md](../002-seguranca-dados/spec.md) (chave Pix, payload local, sem log)

## Problema

Hoje, ao finalizar uma locação (`EndRentalDialog`), "Pix" é só uma das 3 opções de forma de pagamento (`PaymentMethod.pix`) — é um rótulo, não gera nada. O responsável precisa saber a chave Pix de cor ou o operador copia/dita ela na mão. Não existe fluxo de cobrança real dentro do app.

## Objetivo

Quando o operador escolhe "Pix" pra finalizar uma locação, o app mostra um QR Code Pix (BR Code / EMV) já com o valor exato da locação, pronto pra o responsável escanear e pagar — gerado 100% localmente no aparelho.

## Fora de escopo

- Confirmação automática de pagamento (não há API de banco integrada — o operador confirma manualmente que o Pix caiu, igual confirma hoje que recebeu dinheiro/cartão).
- Pix dinâmico com webhook/expiração — é Pix estático (copia-e-cola / QR) com valor fixo da locação.
- Split de pagamento (parte dinheiro + parte Pix).
- Editar chave Pix por brinquedo/operador — uma chave, a do negócio, configurada uma vez.

## Cenários de usuário

1. Dado que o negócio ainda não configurou nome/cidade/chave Pix, quando o operador escolhe "Pix" no fim de uma locação, então o app pede pra configurar isso antes (uma vez só) em vez de travar ou gerar QR inválido — fluxo de "Cartão"/"Dinheiro" continua funcionando normal sem exigir essa configuração.
2. Dado que o negócio já configurou nome/cidade/chave Pix, quando o operador escolhe "Pix" e confirma, então aparece um QR Code com o valor exato da locação (`rental.price`), o nome do recebedor e a cidade corretos.
3. Dado o QR gerado, quando o responsável escaneia num app de banco, então o valor pré-preenchido bate com o que apareceu na tela — nenhuma divergência de centavos por arredondamento.
4. Dado o QR na tela, quando o operador confirma que o pagamento caiu, então a locação finaliza exatamente como finaliza hoje (`state.confirmEnd()`), sem novo status/estado paralelo.
5. Dado o payload Pix gerado, quando outro app de banco valida o CRC16 do BR Code, então ele aceita como válido (checksum correto) — payload malformado é o pior caso possível aqui (dinheiro certo mas QR rejeitado, ou pior, aceito com valor errado).

## Critérios de aceite

- [ ] Tela/seção de configuração do negócio (nome do recebedor, cidade, chave Pix) — nova, não existe hoje. Guardada localmente no aparelho, nunca hardcoded no código-fonte (ver `002`).
- [ ] Gerador de payload BR Code (EMV/Pix) implementado localmente: merchant name, merchant city, chave Pix, valor, txid, com CRC16-CCITT calculado e anexado corretamente.
- [ ] Teste unitário do gerador de payload contra pelo menos 2 payloads Pix conhecidos/vetores de referência (CRC16 confere byte a byte) — isso é testável sem UI e sem device.
- [ ] `EndRentalDialog` — ao selecionar Pix e confirmar, mostra QR Code (novo widget/modal) antes de finalizar de fato; "Cartão" e "Dinheiro" seguem o fluxo atual sem nenhuma etapa extra.
- [ ] Se configuração de Pix ausente, selecionar "Pix" leva a configurar antes, sem quebrar o botão "Confirmar" pras outras duas formas de pagamento.
- [ ] Dependência de geração de QR (ex: `qr_flutter`) avaliada contra o checklist de `002-seguranca-dados` antes de entrar no `pubspec.yaml`.
- [ ] Nenhum valor de chave Pix ou payload aparece em log/print.
- [ ] Teste de widget: fluxo "Pix" com config presente mostra QR; fluxo "Pix" com config ausente mostra o pedido de configuração; "Cartão"/"Dinheiro" inalterados.
- [ ] Suite atual (`test/widget_test.dart`, `integration_test/app_test.dart`) segue passando — o teste de integração que já finaliza uma locação com Pix (`integration_test/app_test.dart:65`) precisa continuar passando ou ser atualizado deliberadamente como parte desta spec, nunca quebrado incidentalmente.

## Requisitos não-funcionais (segurança)

Ver `specs/002-seguranca-dados/spec.md` — chave Pix nunca no git, payload montado localmente sem chamada externa, QR não persiste nem loga.

## Dúvidas em aberto

- Chave Pix é CPF, CNPJ, telefone, e-mail ou chave aleatória? Isso muda só o formato do campo, não a estrutura do payload.
- "Configurar Pix" vira uma aba/tela nova de "Configurações", ou entra dentro de alguma aba existente (ex: Faturamento)? Hoje o app não tem nenhuma tela de config — isso é a primeira.
- Depois de mostrar o QR, o app deve também oferecer o "Pix copia e cola" como texto (pra colar manualmente se o responsável não conseguir escanear), ou só o QR já resolve?
