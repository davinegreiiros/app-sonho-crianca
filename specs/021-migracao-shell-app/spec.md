# Spec: Migração — Shell do app (tab ativa, cabeçalho, nav)

Status: Implemented
Criado: 2026-08-25

Última fatia do roadmap de arquitetura em camadas (ver [specs/010-migracao-arquitetura-camadas](../010-migracao-arquitetura-camadas/spec.md)) — migra os 3 últimos widgets que ainda leem `AppState` direto: `home_shell.dart`, `app_bottom_nav.dart`, `app_header.dart`.

## Problema

Depois da spec 019 (Painel do dia), sobrou só a "casca" do app lendo `AppState` via `context.watch`/`context.select`:

- [home_shell.dart](../../lib/screens/home_shell.dart) — `state.tab` (decide qual `View` mostrar no corpo).
- [app_bottom_nav.dart](../../lib/widgets/app_bottom_nav.dart) — `state.tab` (destaca o item ativo) e `state.setTab(...)` (troca de aba).
- [app_header.dart](../../lib/widgets/app_header.dart) — `state.kicker` (data no cabeçalho) e `state.screenTitle` (título da tela atual).

É a única fatia do estado global que resta acoplada a `View`s de produção — o resto de `AppState` (draft de nova locação, fluxo de encerrar/Pix, catálogo, configurações) não tem mais consumidor de `View` nenhum, só existe porque é usado como atalho de setup em ~18 arquivos de teste (padrão já aceito pela constitution, ver "Fora de escopo" da spec 019).

## Objetivo

`tab`/`kicker`/`screenTitle`/`setTab` saem de `AppState` e viram um `Cubit<EstadoDaTela>` próprio (`lib/ui/features/app_shell/`), injetado nos 3 widgets acima via `BlocBuilder`/`BlocSelector`. Depois desta spec, nenhuma `View`/widget de produção lê `AppState` direto — só os arquivos de teste que o usam como atalho de setup (mantidos, regra de não-quebra).

## Fora de escopo

- Qualquer mudança de comportamento visível (abas, cabeçalho, navegação continuam idênticos).
- Remover `AppState` do projeto ou qualquer um dos seus métodos/campos ainda usados por teste (`submitNew`, `openEnd`, `confirmEnd`, `addToy`, etc.) — API pública estável pros ~18 arquivos de teste que a chamam direto, mesmo raciocínio da spec 019.
- Remover `ChangeNotifierProvider<AppState>` de `main.dart` — continua registrado enquanto `AppState` for usado pelos testes.
- Mexer em `RentalDraft`/fluxo de "nova locação" dentro de `AppState` — já morto pra `View`s (substituído por `NewRentalCubit`, spec 017), mas fora do escopo desta fatia (é remoção de código morto, não migração de leitura de `View`).

## Cenários de usuário

Paridade total:

1. Dado o app aberto, quando o operador toca numa aba da barra inferior, então o corpo troca pra `View` daquela aba e o item ativo fica destacado — idêntico a hoje.
2. Dado o app aberto em qualquer aba, quando o operador olha o cabeçalho, então a data (`kicker`) e o título da tela (`screenTitle`) mostrados batem com a aba atual — idêntico a hoje.
3. Dado o app recém-aberto (estado inicial), quando a primeira tela renderiza, então a aba ativa é "Painel do dia" (`AppTab.home`), mesma aba inicial de hoje.

## Critérios de aceite

- [x] `AppShellCubit` + `AppShellState` (`lib/ui/features/app_shell/view_models/`) — sem Repository injetado (não depende de dado de domínio), expõe `tab`, `kicker`, `screenTitle`, método `setTab(AppTab)`. `AppTab` migrou junto, pra `lib/ui/features/app_shell/view_models/app_shell_state.dart`.
- [x] `home_shell.dart`, `app_bottom_nav.dart`, `app_header.dart` passam a ler `AppShellCubit` (`context.watch`/`context.select`), sem `Provider`/`context.watch<AppState>()`.
- [x] `main.dart` registra `BlocProvider<AppShellCubit>`.
- [x] `AppState.tab`/`setTab`/`kicker`/`screenTitle` — mantidos intactos (18 arquivos de teste chamam direto); `AppTab` agora é re-exportado de `app_shell_state.dart`.
- [x] Teste novo (unit, sem `WidgetTester`) cobrindo `AppShellCubit` (`test/app_shell_cubit_test.dart`).
- [x] `flutter analyze` limpo.
- [x] Suíte de testes existente passa sem alterar nenhum assert (3 arquivos tiveram só o mecanismo de navegação trocado — `AppState.setTab` → `AppShellCubit.setTab` — assert nenhum mudou).

## Requisitos não-funcionais

- `AppShellCubit` testável com `flutter_test` puro, sem `WidgetTester`.

## Dúvidas em aberto

Nenhuma bloqueante.

- **Resolvido (2026-08-25):** `AppShellCubit` sem ticker próprio — `kicker` recalcula só em navegação/troca de aba, não a cada 1s. Decisão do dono do produto: fica melhor sem disparo constante; a data só muda à meia-noite mesmo.
