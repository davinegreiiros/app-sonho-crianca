# Plan: Migração — Configurações do negócio

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

O ponto delicado desta fatia é que `BusinessSettings` tem consumidores fora da tela migrada (`end_rental_dialog.dart`, `pix_qr_sheet.dart`, e `test/pix_flow_test.dart` chamando `AppState.updateBusinessSettings` direto) que só migram na fatia 014. Solução: strangler fig — o `AppState` para de possuir o dado e passa a delegar pro `BusinessSettingsRepository` novo, mantendo sua API pública (`businessSettings` getter, `updateBusinessSettings(...)`) intacta pros consumidores antigos.

1. **`BusinessSettingsLocalService`** — puro wrapper de `SharedPreferences` pras 3 chaves (mesmas chaves que já existiam em `AppState`, só movidas). `load()` retorna `BusinessSettings`, `save(BusinessSettings)` persiste as 3 chaves.
2. **`BusinessSettingsRepository extends ChangeNotifier`** — guarda `BusinessSettings` em memória (`settings` getter síncrono, default `const BusinessSettings()`), `load()` busca do Service e notifica, `update(BusinessSettings)` atualiza em memória + notifica **antes** de persistir (mesma ordem "otimista" que `AppState.updateBusinessSettings` já tinha) e só depois `await` o `save` do Service. Guarda de `_disposed` igual ao padrão já usado em `AppState`.
3. **`BusinessSettingsCubit extends Cubit<BusinessSettingsState>`** — recebe o `Repository` no construtor, estado inicial = `BusinessSettingsState(settings: repository.settings)`, escuta o `Repository` (`addListener`) e reemite quando ele muda, expõe `save({merchantName, merchantCity, pixKey})` que só chama `repository.update(...)`. `close()` remove o listener.
4. **`BusinessSettingsView`** — cópia de `BusinessSettingsScreen` com `context.watch<AppState>()`/`context.read<AppState>()` trocado por `context.watch<BusinessSettingsCubit>()`/`context.read<BusinessSettingsCubit>()`; resto (layout, `TestKeys`, preview do QR via `buildPixPayload`) idêntico.
5. **`AppState`**: `businessSettingsRepository` vira parâmetro nomeado opcional do construtor (mesmo padrão de `notifications`/`LocalRentalNotifier`) — se não informado, cria seu próprio `BusinessSettingsRepository()` (mantém todo `AppState(...)` de teste existente funcionando sem mudança). No construtor, escuta o repository (`addListener(notifyListeners)`) e chama `businessSettingsRepository.load()` (substitui o antigo `_loadBusinessSettings`). `businessSettings` vira getter que retorna `_businessSettingsRepository.settings`; `updateBusinessSettings(...)` vira um repasse pro `_businessSettingsRepository.update(...)`. Remove os 3 `static const _prefs*` e o método `_loadBusinessSettings` antigos — essa lógica agora mora só no Service/Repository.
6. **`main.dart`**: cria **uma instância** de `BusinessSettingsRepository` num `Provider` (acima do `AppState`), passa essa mesma instância pro `ChangeNotifierProvider<AppState>` e pro `BlocProvider<BusinessSettingsCubit>` — é essa instância compartilhada que garante que a tela nova e o `AppState` (mundo antigo) nunca divirjam.
7. **`modal_launchers.dart`**: `openBusinessSettingsScreen` passa a empurrar `BusinessSettingsView` em vez de `BusinessSettingsScreen`. `BusinessSettingsCubit` já está disponível na árvore (provido em `main.dart`, acima do `Navigator`), não precisa de wiring extra no push.
8. Remove `lib/screens/business_settings_screen.dart` e os `.gitkeep` das pastas que passam a ter conteúdo real (`lib/data/repositories/`, `lib/data/services/`, `lib/ui/features/`).

## Arquivos afetados

- `lib/data/services/business_settings_local_service.dart` — novo.
- `lib/data/repositories/business_settings_repository.dart` — novo.
- `lib/ui/features/business_settings/view_models/business_settings_state.dart` — novo (`Equatable`).
- `lib/ui/features/business_settings/view_models/business_settings_cubit.dart` — novo.
- `lib/ui/features/business_settings/views/business_settings_view.dart` — novo (conteúdo movido de `business_settings_screen.dart`).
- `lib/screens/business_settings_screen.dart` — removido.
- `lib/state/app_state.dart` — `businessSettings`/`updateBusinessSettings` viram proxy pro Repository; construtor ganha `businessSettingsRepository` opcional; remove persistência própria.
- `lib/main.dart` — provê `BusinessSettingsRepository` compartilhado + `BlocProvider<BusinessSettingsCubit>`.
- `lib/widgets/modal_launchers.dart` — `openBusinessSettingsScreen` usa `BusinessSettingsView`.
- `lib/data/repositories/.gitkeep`, `lib/data/services/.gitkeep`, `lib/ui/features/.gitkeep` — removidos (pastas deixam de estar vazias).
- `test/business_settings_cubit_test.dart` — novo: cobre Repository + Cubit sem `WidgetTester`.

## Modelo de dados / estado

`BusinessSettings` (domain model) não muda nenhum campo. Novo: `BusinessSettingsState` (classe de estado do Cubit, `Equatable`, um único campo `settings: BusinessSettings`) — não confundir os dois: o domain model é o dado, o `State` é o envelope que o Cubit emite.

## Riscos / dependências

- Maior risco real: `AppState` e a nova tela lerem instâncias *diferentes* de `BusinessSettingsRepository` (bug clássico de migração incremental — duas fontes de verdade). Mitigado pelo item 6 do plano (instância única no `main.dart`) e pelo cenário de usuário #3 da spec, que existe justamente pra pegar essa regressão.
- Depende da fundação da spec 010 (pastas + dependências) já implementada.
- Nenhum dos consumidores fora de escopo (`end_rental_dialog.dart`, `pix_qr_sheet.dart`) é tocado — só validados via teste existente (`pix_flow_test.dart`) continuando verde.

## Alternativas consideradas

- **`businessSettingsRepository` obrigatório no construtor de `AppState`.** Descartado: quebraria todo `AppState(...)`/`AppState(notifications: ...)` já escrito em `test/rental_notifications_test.dart`, `extend_rental_test.dart`, `open_ended_rental_test.dart`, `catalog_tickets_test.dart` — mudança desnecessária pra esses testes, que nem tocam em configurações do negócio. Parâmetro opcional com default resolve sem tocar neles.
- **`AppState` deixar de expor `businessSettings`/`updateBusinessSettings` e os dois widgets (`end_rental_dialog`, `pix_qr_sheet`) já migrarem pro `BusinessSettingsRepository`/`Cubit` direto nesta fatia.** Descartado: contraria o roadmap fatiado (spec 010) — essa migração pertence à fatia 014, junto com o resto do fluxo de locação.
