# Spec: Migração — Painel do dia (Home)

Status: Implemented
Criado: 2026-08-24

Última fatia do roadmap de locação (ver [specs/010-migracao-arquitetura-camadas](../010-migracao-arquitetura-camadas/spec.md)) — migra `home_tab.dart`, a única tela ainda em `AppState`.

## Problema

`home_tab.dart` lê `state.recentActivity`, `state.activeRentals.length`, `state.toys.fold(... state.toyAvailable ...)`, `state.doneToday.length`, `state.homeTotalToday`, `state.toyById`, `state.fmtMoney`/`whenLabel`. Nenhum desses (`recentActivity`/`doneToday`/`homeTotalToday`) tem outro consumidor — mesma situação da fatia 014 (Relatório): dá pra remover de vez de `AppState`, não só proxyar.

## Objetivo

`home_tab.dart` vira `HomeCubit` + `HomeView` (`lib/ui/features/home/`), cross-repository (`ToyRepository` + `RentalRepository`, igual `ReportCubit`), com um ticker de 1s próprio (mantém os rótulos "há N min" atualizados em tempo real, mesma garantia que `AppState._ticker` já dava). `AppState.recentActivity`/`doneAll`/`doneToday`/`homeTotalToday`/`_startOfDay` são removidos — sem outro consumidor. `AppState.activeRentals`/`toyAvailable`/`toyById` **não mudam** (usados por testes direto e por `ActiveRentalsCubit`/`ToyCatalogCubit` via Repository compartilhado).

Esta é a última fatia do roadmap de locação — depois dela, nenhuma `View` de tela lê `AppState` diretamente (só os ~30 arquivos de teste que chamam seus métodos como atalho de setup, o que a constitution já aceita manter).

## Fora de escopo

- Qualquer mudança de comportamento visível.
- Remover `AppState` do projeto — continua existindo como API pública estável pros testes que a usam direto (regra de não-quebra).

## Cenários de usuário

Paridade total:

1. Dado o app aberto, quando o operador vê "Painel do dia", então o total faturado hoje, contagem de locações finalizadas, "em uso"/"disponíveis" e atividade recente (até 4 itens, ativas + finalizadas hoje, mais recentes primeiro) aparecem idênticos a hoje.
2. Dado uma locação criada/estendida/cancelada/finalizada em qualquer tela (`NewRentalCubit`/`ActiveRentalsCubit`, ou `AppState` direto em teste), quando o operador volta pro Painel, então os números refletem a mudança — prova de que `HomeCubit` lê a mesma fonte de verdade.

## Critérios de aceite

- [x] `HomeCubit` + `HomeState` (`lib/ui/features/home/view_models/`) — injeta `ToyRepository` + `RentalRepository` (+ `ComputeToyAvailability`, já existente), ticker de 1s próprio. Expõe `recentActivity`, `activeCount`, `availableCount`, `doneTodayCount`, `homeTotalToday`, `toyById`.
- [x] `HomeView` (`lib/ui/features/home/views/`) substitui `lib/screens/tabs/home_tab.dart` — mesmo layout, mesma `TestKey` (`homeNewRentalButton`), usa `formatMoney`/`formatRelativeTime` de `lib/domain/formatters.dart`.
- [x] `home_shell.dart` aponta pra `HomeView`.
- [x] `AppState.recentActivity`/`doneAll`/`doneToday`/`homeTotalToday`/`_startOfDay` removidos (sem outro consumidor, confirmado por grep). `AppState.activeRentals`/`toyAvailable`/`toyById`/`fmtMoney`/`whenLabel` continuam intactos.
- [x] `main.dart` registra `BlocProvider<HomeCubit>`.
- [x] Teste novo (unit, sem `WidgetTester`) cobrindo `HomeCubit`.
- [x] `flutter analyze` limpo.
- [x] Toda a suíte de testes existente passa sem alterar nenhum assert (93 testes, todos verdes).

## Requisitos não-funcionais

- `HomeCubit` testável com `flutter_test` puro, sem `WidgetTester`.

## Dúvidas em aberto

Nenhuma bloqueante.
