# Plan: QR Code Pix na finalização de locação

Referência: [spec.md](spec.md), [specs/002-seguranca-dados/spec.md](../002-seguranca-dados/spec.md).

## Abordagem técnica

1. **Payload BR Code (EMV/Pix) — sem dependência nova.** Construído à mão em `lib/services/pix_payload.dart`: função pura `buildPixPayload({merchantName, merchantCity, pixKey, amount, txid})` que monta os campos TLV do padrão EMVCo/Pix estático e anexa o CRC16-CCITT (poly `0x1021`, init `0xFFFF`) calculado localmente. Nenhuma lib externa monta isso — mais fácil de auditar (requisito de `002`: "montado 100% localmente") e evita depender de um pacote de terceiro pra algo que envolve dinheiro.
2. **Renderização do QR — 1 dependência nova.** `qr_flutter` (`QrImageView`): só desenha, não monta payload nem faz rede. Avaliado contra o checklist de `002`: mantido ativamente, sem permissão nativa, offline.
3. **Configuração do negócio.** `BusinessSettings` (nome do recebedor, cidade, chave Pix) — novo model simples, persistido com `shared_preferences` (2ª dependência nova; plataforma padrão, sem permissão, só key-value local). Guardado só no aparelho, nunca no git (é dado digitado em runtime pelo usuário, não um valor no código-fonte).
4. `AppState`: carrega `BusinessSettings` de forma assíncrona no `_seed()`/construtor (padrão comum: começa com valores vazios, `notifyListeners()` quando o `SharedPreferences` resolve); ganha `updateBusinessSettings(...)` e getter `pixConfigured`.
5. **Tela de configuração:** ícone de engrenagem no `AppHeader` (canto onde hoje só tem os 3 pontos animados) abre `BusinessSettingsSheet` (bottom sheet, mesmo padrão de `AddToySheet`) com os 3 campos.
6. **Fluxo no fim de locação:** `EndRentalDialog` — ao escolher "Pix" e tocar "Confirmar":
   - Se `!pixConfigured`: fecha o dialog atual e abre `BusinessSettingsSheet` direto (com uma dica de que precisa configurar antes) em vez de travar o botão.
   - Se configurado: abre `PixQrSheet` (novo modal) mostrando `QrImageView` do payload + o texto "copia e cola" com botão de copiar (`Clipboard.setData`). Um botão "Concluir" nesse sheet chama `state.confirmEnd()` (que já resolve o preço via `computeFinalPrice` — spec `006` — antes de gravar) e fecha tudo.
   - "Cartão"/"Dinheiro": comportamento idêntico ao de hoje, sem nenhuma etapa nova.
7. Resumo do `EndRentalDialog` já usa `computeFinalPrice` (feito em `006`) — o valor mostrado no QR é o mesmo número, nunca diverge.

## Arquivos afetados

- `pubspec.yaml` — `qr_flutter`, `shared_preferences`.
- `lib/services/pix_payload.dart` — novo, payload EMV/Pix + CRC16 (puro, sem I/O).
- `lib/models/business_settings.dart` — novo model + serialização simples.
- `lib/state/app_state.dart` — carregamento/persistência de `BusinessSettings`, `pixConfigured`.
- `lib/widgets/business_settings_sheet.dart` — novo.
- `lib/widgets/pix_qr_sheet.dart` — novo.
- `lib/widgets/app_header.dart` — ícone de engrenagem.
- `lib/widgets/end_rental_dialog.dart` — branch de confirmação por forma de pagamento.
- `lib/widgets/modal_launchers.dart` — `showBusinessSettingsSheet`, `showPixQrSheet`.
- `android/app/src/main/AndroidManifest.xml` / `ios/Runner/Info.plist` — nenhuma permissão nova esperada (`qr_flutter`/`shared_preferences` não pedem nada); confirmar no fim que nada mudou aqui — se `flutter build` gerar algo automaticamente, documentar por quê.
- `test/` — teste unitário do payload (CRC16 contra vetores conhecidos) + teste de widget do fluxo Pix configurado/não-configurado.

## Modelo de dados / estado

`BusinessSettings` é estado novo, independente de `Toy`/`Rental` — não migra nada existente. `Rental`/`AppState` ganham só o getter `pixConfigured` e a chamada ao payload builder; `computeFinalPrice` (de `006`) é reusado sem alteração.

## Riscos / dependências

- Depende de `006` (já `Implemented`) pro cálculo de preço usado no resumo/QR.
- Depende de `002` como guard-rail de segurança (chave nunca no git, payload local, sem log).
- Risco de CRC16 errado gerar QR inválido — mitigado com teste unitário contra vetores conhecidos antes de qualquer UI.
- `SharedPreferences` é assíncrono; `AppState` hoje é síncrono no boot — mitigado com estado "carregando" implícito (campos vazios até resolver, sem travar a UI).

## Alternativas consideradas

- Usar um pacote pronto pra montar o payload Pix inteiro (não só desenhar o QR): descartado — `002` pede que o payload seja auditável/local; um builder de ~80 linhas é mais simples de revisar do que confiar numa lib de terceiro pra algo com dinheiro envolvido.
- `flutter_secure_storage` pra chave Pix em vez de `shared_preferences`: considerado, mas adiciona keychain nativo por plataforma pra um dado que já é local-only e não é PII de criança — `shared_preferences` já atende ao requisito de `002` ("nunca hardcoded no código/git"). Revisitar se o negócio pedir mais blindagem.
