# Tasks: Revisão de Design v3

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `pubspec.yaml`: adicionar `flutter_svg`, registrar `assets/icons/category/`; `flutter pub get`.
- [x] T2 — 6 SVGs em `assets/icons/category/` (eletrico, inflavel, passeio, aquatico, radiocontrole, outro) com paths do design.
- [x] T3 — `ToyCategory.icon` + `ToyCategory.ink` (extensions em `lib/models/toy.dart`), token neutro "Outro" em `app_colors.dart` se faltar.
- [x] T4 — `lib/widgets/category_icon.dart` (novo widget de ícone SVG tintado).
- [x] T5 — `_Tag` (catalog card) e `_CategoryPicker` (add_toy_sheet) passam a mostrar o ícone.
- [x] T6 — `_TicketStub`: retícula de pontos quando livre, contorno 45% quando em uso.
- [x] T7 — `buildPixPayload` chamada em `pix_qr_sheet.dart` passa `txid` real (id da locação saneado); mesmo valor vira "nº de documento" exibido.
- [x] T8 — `AppState`: método público pra "Trocar forma" (voltar de `endShowPixQr=true` sem fechar o dialog).
- [x] T9 — `PixQrSheet` reescrito: moldura de cupom, faixa CMY, doc, "Aguardando confirmação" pulsando, botão "Trocar forma". (Ver nota abaixo: um layout específico do botão "Copiar" quebrou `WidgetTester.tap` — resolvido revertendo pro padrão `TextButton.icon` já provado estável; não reintroduzir `CrossAxisAlignment.stretch` num Row com `Pressable(SizedBox(height:N, ElevatedButton))`.)
- [x] T10 — `BusinessSettingsScreen` (novo, `lib/screens/`) substitui `BusinessSettingsSheet`; `modal_launchers.dart`/`app_header.dart`/`end_rental_dialog.dart` atualizados pra `Navigator.push`; prévia de QR mini ao lado da chave.
- [x] T11 — `active_tab.dart`: clock magenta, trilho tracejado "sem fim" (novo widget de animação), bloco "Estimado agora", CTA "Parar e cobrar" só pra `openEnded`.
- [x] T12 — `test_keys.dart`: chaves novas necessárias pros testes de T13.
- [x] T13 — testes: ícone de categoria certo por tipo (`test/design_v3_test.dart`); canhoto livre vs em uso (cobertura já existente em `catalog_tickets_test.dart`, comportamento inalterado); CTA "Parar e cobrar" em tempo corrido vs "Finalizar" em fixo; Configurações abre como tela cheia (não bottom sheet), com botão de voltar funcional.
- [x] T14 — `flutter analyze` limpo (0 issues) + suíte de testes passando (33/33) + checklist de `spec.md` revisado.

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
