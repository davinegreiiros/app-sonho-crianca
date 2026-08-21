# Tasks: QR Code Pix na finalização de locação

Referência: [spec.md](spec.md) + [plan.md](plan.md).

- [x] T1 — `pubspec.yaml`: `qr_flutter`, `shared_preferences`
- [x] T2 — `lib/services/pix_payload.dart`: builder EMV/Pix + CRC16, puro
- [x] T3 — teste unitário do CRC16/payload — CRC contra vetor padrão `123456789`→`0x29B1`, self-consistência, truncamento
- [x] T4 — `BusinessSettings` model + persistência em `AppState` (`SharedPreferences`)
- [x] T5 — `BusinessSettingsSheet` + engrenagem no `AppHeader` + launcher
- [x] T6 — `PixQrSheet` (QR + copia-e-cola + botão copiar) — renderizado inline dentro do `EndRentalDialog` (não como rota separada, ver nota abaixo)
- [x] T7 — `EndRentalDialog`: branch Pix configurado / não-configurado / Cartão-Dinheiro inalterado
- [x] T8 — teste de widget: `test/pix_flow_test.dart` — Pix sem config → abre config; Pix com config → mostra QR → só finaliza no "Concluir"; Cartão inalterado
- [x] T9 — checklist de segurança de `002` revisado: nenhuma chave hardcoded (grep confere), payload 100% local, sem log de dado sensível, manifests sem diff (nenhuma permissão nova)
- [x] T10 — `flutter analyze` limpo, `flutter test` (22 testes) passando

**Nota de implementação (desvio do plan.md):** `PixQrSheet` não é aberto como uma nova rota via `showGeneralDialog` separada — isso criaria uma corrida real entre `closeEnd()` (chamado ao fechar a rota do `EndRentalDialog`) resetando `endingId`/`endPayment` e o botão "Concluir" do QR ainda precisando deles pra chamar `confirmEnd()`. Em vez disso, `AppState.endShowPixQr` alterna o *conteúdo* renderizado dentro da mesma rota/dialog já aberto. Dois bugs reais pegos e corrigidos nesse meio-tempo: (1) `Navigator.of(context)` chamado depois de `confirmEnd()` — o rebuild síncrono do `notifyListeners()` já desmonta o widget antes do `.pop()` rodar; corrigido capturando o `NavigatorState` antes. (2) `RenderFlex` overflow de 4px do `PixQrSheet` em tela baixa — corrigido com `Flexible`+`SingleChildScrollView` só na região do QR/payload, mantendo título e botões fixos.

## Correção pós-implementação (2026-08-20)

**Bug reportado pelo usuário:** em locação tempo corrido (spec 006) paga por Pix, `PixQrSheet` gerava o QR chamando `computeFinalPrice(rental)` no momento de abrir a tela, mas `confirmEnd()` recalculava o mesmo `computeFinalPrice(rental)` de novo ao tocar "Pagamento recebido, concluir". Como o relógio de tempo corrido não para enquanto o QR está na tela, se o cliente demorasse pra pagar o valor cobrado/registrado ficava maior que o valor codificado no QR que ele escaneou — cobrança silenciosamente errada.

**Fix:** `AppState.endFrozenPrice` — congelado em `showPixQrStep()` (mesmo instante em que a etapa do QR abre), reusado tanto por `PixQrSheet` (pra gerar o payload) quanto por `confirmEnd()` (`r.price = endFrozenPrice ?? computeFinalPrice(r)`). Resetado em `openEnd`/`closeEnd`/depois de `confirmEnd`. Pagamento em Cartão/Dinheiro não passa pela etapa de QR — `endFrozenPrice` fica `null` pra eles, comportamento inalterado (recalcula na hora, como sempre foi).

Teste de regressão: `test/open_ended_rental_test.dart` — "Pix QR freezes the price — a slow-to-pay customer is not charged more" (congela em 10min/R$5,00, simula mais 6min passando com o QR aberto, confirma que cobra R$5,00 e não R$8,00). 27 testes no total, `flutter analyze` limpo.

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`. Se algo quebrar no meio, parar ali (regra de não-quebra), não emendar.
