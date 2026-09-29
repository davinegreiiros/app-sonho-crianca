# Spec: Migração — Serviços de locação (fundação)

Status: Implemented
Criado: 2026-08-23

Fatia 016 do roadmap em [specs/010-migracao-arquitetura-camadas](../010-migracao-arquitetura-camadas/spec.md) — decisão de sub-fatiar a antiga "016 Locação completa" (ver "Aprendizado da fatia 016" lá). Esta spec só move `lib/services/pix_payload.dart` e `lib/notifications/*` pra `lib/data/services/` — nenhum `Cubit`/`View` novo, nenhuma mudança de lógica.

## Problema

`lib/services/pix_payload.dart` (builder puro do payload Pix) e `lib/notifications/*` (`RentalNotifier` — interface, `LocalRentalNotifier` — implementação real, `notification_texts.dart` — textos) já são código bem desenhado (funções puras / interface injetável, usada por um fake em teste desde a spec 005) — só não estão na pasta que a arquitetura em camadas define (`lib/data/services/`). Migrar a locação de verdade (fatias seguintes) fica mais simples com esse realinhamento já feito antes.

## Objetivo

`lib/services/pix_payload.dart` e os 3 arquivos de `lib/notifications/` passam a viver em `lib/data/services/` — mesmo conteúdo, mesmos nomes de arquivo, só a pasta muda. `lib/services/` e `lib/notifications/` deixam de existir.

## Fora de escopo

- Qualquer `Cubit`/`View` de locação — vem nas sub-fatias seguintes (017+).
- Mudar a lógica de `buildPixPayload`, `RentalNotifier`, `LocalRentalNotifier` ou os textos de notificação — é `git mv` + ajuste de import, nada além disso.
- `AppState` continua chamando essas funções/classes exatamente como antes — só o caminho do import muda.

## Cenários de usuário

Paridade total, sem nenhum comportamento novo — é reorganização de pastas:

1. Dado o app rodando normalmente, quando uma locação é criada/estendida/cancelada/finalizada, então as notificações continuam sendo agendadas/canceladas exatamente como antes.
2. Dado o QR Pix sendo gerado (preview em Configurações, ou na finalização de locação), quando o operador olha o QR, então o conteúdo é idêntico a antes.

## Critérios de aceite

- [x] `lib/data/services/pix_payload.dart` — movido de `lib/services/`, mesmo conteúdo.
- [x] `lib/data/services/rental_notifier.dart`, `lib/data/services/local_rental_notifier.dart`, `lib/data/services/notification_texts.dart` — movidos de `lib/notifications/`, mesmo conteúdo.
- [x] `lib/services/` e `lib/notifications/` removidos (pastas vazias).
- [x] Imports atualizados em `lib/state/app_state.dart`, `lib/ui/features/business_settings/views/business_settings_view.dart`, `lib/widgets/pix_qr_sheet.dart`, `test/pix_payload_test.dart`, `test/fakes/fake_rental_notifier.dart`.
- [x] `flutter analyze` limpo.
- [x] Toda a suíte de testes existente passa sem alterar nenhum assert (71 testes, todos verdes).

## Requisitos não-funcionais

Nenhum além dos já cobertos pela regra de não-quebra da constitution.

## Dúvidas em aberto

Nenhuma bloqueante.
