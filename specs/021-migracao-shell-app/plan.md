# Plan: Migração — Shell do app (tab ativa, cabeçalho, nav)

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

`AppShellCubit` é um `Cubit<AppShellState>` sem Repository injetado — não lê dado de domínio, só guarda a aba ativa (`AppTab`). Diferente de `HomeCubit` (019), sem ticker (dúvida em aberto resolvida: `kicker` recalcula só quando o `Cubit` reemite, ou seja, em `setTab`/troca de navegação — não a cada 1s).

1. **`AppTab`** — move de `lib/state/app_state.dart` pra `lib/ui/features/app_shell/view_models/app_shell_state.dart`. `lib/state/app_state.dart` passa a importar `AppTab` de lá (não duplica o enum) — `AppState.tab`/`setTab` continuam existindo pros testes, só o tipo muda de dono.
2. **`AppShellState`** (Equatable) — `tab: AppTab`. `kicker`/`screenTitle` viram getters computados no próprio `State` (dependem só de `tab` e do relógio no momento da leitura, não precisam ser campo).
3. **`AppShellCubit`** — `setTab(AppTab)` emite novo `AppShellState`. Estado inicial `AppTab.home`, igual `AppState._seed`/campo `tab` hoje.
4. **`home_shell.dart`**: `context.select((AppShellCubit c) => c.state.tab)` no lugar de `context.select((AppState s) => s.tab)`.
5. **`app_bottom_nav.dart`**: `context.watch<AppShellCubit>()`, `state.tab`/`() => context.read<AppShellCubit>().setTab(...)`.
6. **`app_header.dart`**: `context.watch<AppShellCubit>()`, `state.kicker`/`state.screenTitle`.
7. **`main.dart`**: `BlocProvider<AppShellCubit>` na `MultiBlocProvider` existente. `ChangeNotifierProvider<AppState>` continua (18 arquivos de teste dependem dele) — `AppState` deixa de precisar saber de `tab` só pra esses 3 widgets, mas mantém `tab`/`setTab`/`kicker`/`screenTitle` como estão hoje (não remove, não duplica lógica — só para de ser lido por `View` de produção).

## Arquivos afetados

- `lib/ui/features/app_shell/view_models/app_shell_state.dart` — novo (`AppTab` + `AppShellState`).
- `lib/ui/features/app_shell/view_models/app_shell_cubit.dart` — novo.
- `lib/state/app_state.dart` — `enum AppTab` removido daqui, reimportado de `app_shell_state.dart`; `tab`/`setTab`/`kicker`/`screenTitle` ficam intactos (assinatura e comportamento).
- `lib/screens/home_shell.dart` — troca `AppState` por `AppShellCubit`.
- `lib/widgets/app_bottom_nav.dart` — troca `AppState` por `AppShellCubit`.
- `lib/widgets/app_header.dart` — troca `AppState` por `AppShellCubit`.
- `lib/main.dart` — registra `BlocProvider<AppShellCubit>`.
- `test/app_shell_cubit_test.dart` — novo.

## Modelo de dados / estado

`AppShellState` novo (Equatable, só `tab`). Nenhum domain model (`Toy`/`Rental`/`BusinessSettings`) muda. `AppTab` já existia (movido, não recriado) — qualquer teste que hoje importa `AppTab` de `state/app_state.dart` continua funcionando (re-export).

## Riscos / dependências

- Risco baixo — mesmo perfil das fatias 014/019 (sem consumidor de `View` fora de escopo depois da migração).
- Depende só de 019 (última fatia antes desta a tocar `AppState`).
- `AppTab` é usado por ~18 testes que chamam `AppState` direto (`state.tab`, `AppTab.home`, etc.) — mover o enum de arquivo exige um `export`/import em `app_state.dart` pra não quebrar esses imports (`import '.../state/app_state.dart' show AppTab;` continua resolvendo).
- Última fatia do roadmap de arquitetura em camadas (spec 010) do ponto de vista de "nenhuma View lê AppState direto" — depois dela só sobra `AppState` como fixture de teste, sem consumidor de produção nenhum.

## Alternativas consideradas

- **Colocar `kicker`/`screenTitle` dentro de `HomeState`/`HomeCubit`** (já existe, evita Cubit novo). Descartado — `kicker`/`screenTitle` aparecem em toda aba (cabeçalho fixo do shell), não só na Home; acoplar ao `HomeCubit` faria `app_header.dart` depender de um Cubit de uma feature que pode não estar montada (`ActiveTabView`/`CatalogView`/`ReportView` não instanciam `HomeCubit`).
- **Manter ticker de 1s no `AppShellCubit`** (paridade literal com `AppState._ticker`). Descartado por decisão do dono do produto (spec.md, dúvida resolvida) — sem ganho perceptível (`kicker` só muda à meia-noite) e evita rebuild constante do cabeçalho.
