# Tasks: Migração — Serviços de locação (fundação)

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — `git mv` de `pix_payload.dart`, `rental_notifier.dart`, `local_rental_notifier.dart`, `notification_texts.dart` pra `lib/data/services/`. Removidas `lib/services/`/`lib/notifications/` vazias.
- [x] T2 — Atualizados imports em `lib/state/app_state.dart`, `lib/ui/features/business_settings/views/business_settings_view.dart`, `lib/widgets/pix_qr_sheet.dart`.
- [x] T3 — Atualizados imports em `test/pix_payload_test.dart`, `test/fakes/fake_rental_notifier.dart`.
- [x] T4 — `flutter analyze` limpo. (Bônus: 4 comentários de doc com referência de fatia desatualizada — `formatters.dart`, `toy_repository.dart`, `business_settings_repository.dart`, `compute_toy_availability.dart` — corrigidos pra `fatia 017+`/descrição precisa, já que "016" mudou de significado.)
- [x] T5 — `flutter test` completo, sem alterar nenhum assert existente (71 testes, todos verdes — mesma contagem da 015, migração é puramente mecânica).
- [x] T6 — Revisão manual dos critérios de aceite do `spec.md` + atualizar `specs/README.md` (linha 016 vira `Implemented`).

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented`.
