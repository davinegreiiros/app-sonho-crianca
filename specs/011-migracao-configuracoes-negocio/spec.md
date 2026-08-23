# Spec: Migração — Configurações do negócio (primeira fatia real)

Status: Implemented
Criado: 2026-08-22

Fatia 011 do roadmap definido em [specs/010-migracao-arquitetura-camadas](../010-migracao-arquitetura-camadas/spec.md). Primeiro `Repository`/`Cubit`/`View` reais da migração — valida o padrão antes de ir pras fatias maiores (catálogo, relatório, locação).

## Problema

`lib/screens/business_settings_screen.dart` lê e grava `BusinessSettings` direto no `AppState` (que também persiste em `SharedPreferences` por conta própria) — mistura tela, estado de negócio e persistência no mesmo lugar, exatamente o padrão que a spec 010 documentou como gargalo.

Complicador real desta fatia (não existia na fundação 010): `AppState.businessSettings` também é lido fora da tela de configurações — por `end_rental_dialog.dart` (decide se abre a tela de config antes do Pix) e `pix_qr_sheet.dart` (gera o QR) — e esses dois consumidores só migram na fatia 014. Então essa migração não pode duplicar a fonte de verdade: enquanto 014 não chega, o `AppState` (mundo antigo) e o novo `Cubit` (mundo novo) precisam enxergar exatamente o mesmo dado.

## Objetivo

`BusinessSettings` passa a ter um dono único fora do `AppState`: `BusinessSettingsRepository` (`lib/data/repositories/`), alimentado por `BusinessSettingsLocalService` (`lib/data/services/`, encapsula o `SharedPreferences`). A tela de configurações vira `BusinessSettingsCubit` + `BusinessSettingsView` (`lib/ui/features/business_settings/`). `AppState` deixa de persistir/possuir o dado e passa a só espelhar o `Repository` (compatibilidade pros consumidores ainda não migrados), sem duplicar estado nem comportamento.

## Fora de escopo

- Migrar `end_rental_dialog.dart` ou `pix_qr_sheet.dart` para Cubit — continuam lendo `AppState.businessSettings` (que agora é um proxy pro Repository) até a fatia 014.
- Qualquer mudança de comportamento visível, layout, cópia de texto ou fluxo de tela.
- Use case dedicado — CRUD simples (decisão já registrada na spec 010): `BusinessSettingsCubit` fala direto com `BusinessSettingsRepository`.

## Cenários de usuário

Paridade total — mesmo critério da spec 010, agora cobrindo também a ponte com o `AppState`:

1. Dado o app recém-aberto sem configuração salva, quando o operador abre "Configurações" (ícone de engrenagem), então vê os campos vazios, preenche nome/cidade/chave Pix e salva — comportamento idêntico a antes.
2. Dado configurações já salvas, quando o operador reabre a tela, então os campos vêm preenchidos com o valor persistido (via `BusinessSettingsRepository`, não mais via leitura direta de `AppState`).
3. Dado configurações salvas pela nova tela, quando o operador finaliza uma locação escolhendo Pix (fluxo em `end_rental_dialog.dart`/`pix_qr_sheet.dart`, ainda no mundo antigo), então o QR usa exatamente o valor salvo — prova de que as duas pontas continuam vendo o mesmo dado.
4. Dado nenhuma configuração salva, quando o operador tenta finalizar uma locação com Pix, então é redirecionado pra tela de configurações — mesmo comportamento de antes (`AppState.businessSettings.isConfigured` continua funcionando).

## Critérios de aceite

- [x] `BusinessSettingsLocalService` (`lib/data/services/`) encapsula toda leitura/escrita das 3 chaves em `SharedPreferences`, sem lógica de UI ou de `AppState`.
- [x] `BusinessSettingsRepository` (`lib/data/repositories/`) é a única fonte de verdade em memória de `BusinessSettings`: expõe `settings` (getter síncrono), `load()` e `update(...)`, notifica mudanças (mesmo padrão `ChangeNotifier`+`_disposed` já usado em `AppState`).
- [x] `BusinessSettingsCubit` (`lib/ui/features/business_settings/view_models/`) com `BusinessSettingsState` (`equatable`) — consome o `Repository`, expõe estado atual e um método de salvar.
- [x] `BusinessSettingsView` (`lib/ui/features/business_settings/views/`) substitui `lib/screens/business_settings_screen.dart` — mesma UI, mesmas `TestKeys`, lendo/gravando via `BusinessSettingsCubit` em vez de `AppState`.
- [x] `lib/screens/business_settings_screen.dart` removido; `lib/widgets/modal_launchers.dart` aponta pra `BusinessSettingsView`.
- [x] `AppState.businessSettings` e `AppState.updateBusinessSettings(...)` continuam existindo com a mesma assinatura (usados por `end_rental_dialog.dart`, `pix_qr_sheet.dart` e por `test/pix_flow_test.dart` diretamente), agora delegando pro `BusinessSettingsRepository` compartilhado — `AppState` não chama mais `SharedPreferences` diretamente pra isso.
- [x] `AppState` continua widgets-compatível sem mudar assinatura de construtor pros call sites existentes: `businessSettingsRepository` é parâmetro nomeado **opcional** (mesmo padrão de `notifications`), default cria seu próprio `BusinessSettingsRepository()` — nenhum `AppState(...)` em `test/` precisou mudar.
- [x] `main.dart` cria **uma única instância** de `BusinessSettingsRepository` (via `ChangeNotifierProvider`), compartilhada entre `AppState` e `BusinessSettingsCubit` via `Provider`/`BlocProvider` — essa é a instância real usada em produção (a instância default do item acima só existe pra não quebrar os testes que constroem `AppState()` sozinho, sem tela de configurações no ar).
- [x] Teste novo (unit, sem `WidgetTester`, com `bloc_test`) cobrindo `BusinessSettingsRepository`/`BusinessSettingsCubit`: estado inicial, `update`/`save` persiste e emite o novo estado, e sincronia com `AppState` via a mesma instância de `Repository`.
- [x] `flutter analyze` limpo.
- [x] Toda a suíte de testes existente passa sem alterar asserts (`design_v3_test.dart` "gear icon...", `pix_flow_test.dart`, etc. — 44 testes, todos verdes).

## Requisitos não-funcionais

- Fonte de verdade única durante a transição: nunca pode existir um valor de `BusinessSettings` em `AppState` divergente do `BusinessSettingsRepository` — é regressão, não só "não-ideal" (cenário 3 acima é o teste de fumaça disso).
- `BusinessSettingsCubit`/`BusinessSettingsRepository` testáveis com `flutter_test` puro (sem `WidgetTester`), conforme prometido na spec 010.

## Dúvidas em aberto

Nenhuma — decisões técnicas (Repository único, Cubit fino, sem use case, `AppState` como proxy compatível) já derivadas das decisões da spec 010 e descritas acima.
