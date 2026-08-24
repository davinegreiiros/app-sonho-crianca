# Plan: Migração — Serviços de locação (fundação)

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Puro `git mv` + import fix, igual à fundação de modelos da spec 010. Só 5 arquivos consomem esses caminhos hoje (confirmado por grep), então o raio de mudança é pequeno e mecânico.

1. `git mv lib/services/pix_payload.dart lib/data/services/pix_payload.dart`.
2. `git mv lib/notifications/rental_notifier.dart lib/data/services/rental_notifier.dart`, idem pra `local_rental_notifier.dart` e `notification_texts.dart`.
3. Remove `lib/services/` e `lib/notifications/` (vazias).
4. Atualiza import em `lib/state/app_state.dart` (`../notifications/*` → `../data/services/*`), `lib/ui/features/business_settings/views/business_settings_view.dart` (`../../../../services/pix_payload.dart` → `../../../../data/services/pix_payload.dart`), `lib/widgets/pix_qr_sheet.dart` (`../services/pix_payload.dart` → `../data/services/pix_payload.dart`), `test/pix_payload_test.dart` (`package:sonho_de_crianca/services/pix_payload.dart` → `package:sonho_de_crianca/data/services/pix_payload.dart`), `test/fakes/fake_rental_notifier.dart` (`package:sonho_de_crianca/notifications/rental_notifier.dart` → `package:sonho_de_crianca/data/services/rental_notifier.dart`).
5. `local_rental_notifier.dart`'s próprio import interno (`import 'rental_notifier.dart';`) não muda — os dois arquivos se movem juntos pra mesma pasta nova.

## Arquivos afetados

- `lib/data/services/pix_payload.dart` — novo (movido).
- `lib/data/services/rental_notifier.dart`, `local_rental_notifier.dart`, `notification_texts.dart` — novos (movidos).
- `lib/services/`, `lib/notifications/` — removidos.
- `lib/state/app_state.dart`, `lib/ui/features/business_settings/views/business_settings_view.dart`, `lib/widgets/pix_qr_sheet.dart` — import atualizado.
- `test/pix_payload_test.dart`, `test/fakes/fake_rental_notifier.dart` — import atualizado.

## Modelo de dados / estado

Nenhum. Nenhuma classe/função muda de assinatura ou comportamento.

## Riscos / dependências

- Risco muito baixo — mecânico, escopo pequeno (5 arquivos consumidores), já confirmado por grep antes de começar.
- Depende de 013 (`RentalRepository`) só no sentido de que essa é a ordem do roadmap — não há dependência técnica real desta fatia nele.

## Alternativas consideradas

- **Não mexer nisso agora, migrar tudo junto com a primeira fatia de View de locação.** Descartado — separar o "mover arquivo" (mecânico) do "criar Cubit/View" (com risco de comportamento) segue o mesmo raciocínio que já valeu a pena nas fatias 010 e 013.
