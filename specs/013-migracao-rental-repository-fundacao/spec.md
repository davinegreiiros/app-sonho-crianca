# Spec: Migração — RentalRepository (fundação)

Status: Implemented
Criado: 2026-08-23

Fatia 013 do roadmap em [specs/010-migracao-arquitetura-camadas](../010-migracao-arquitetura-camadas/spec.md) — nasceu do "Aprendizado da fatia 013" lá registrado: nem `report_tab.dart` nem `catalog_tab.dart` podiam virar fatia própria sem `RentalRepository` existir primeiro. Esta spec só cria o Repository — nenhuma tela ou Cubit novo.

## Problema

`AppState.rentals` é hoje uma lista mutável possuída direto pelo `AppState`, com toda a regra de negócio de locação (criar, estender, cancelar, encerrar) misturada com estado de UI (draft, diálogo de encerramento, passo do QR Pix). `report_tab.dart` e `catalog_tab.dart` — as próximas fatias — precisam de uma fonte de verdade de `Rental` separada antes de poderem migrar.

## Objetivo

`Rental` passa a ter um dono único fora do `AppState`: `RentalRepository` (`lib/data/repositories/`), possuindo a lista e as duas únicas operações estruturais que existem hoje (adicionar uma locação nova, remover uma cancelada). `AppState.rentals` vira proxy pro Repository — exatamente como já aconteceu com `Toy` (012) e `BusinessSettings` (011) — sem migrar nenhuma tela, Cubit ou fluxo ainda.

## Fora de escopo

- Qualquer `Cubit`/`View` novo — é fundação pura, igual a spec 010 foi pra arquitetura como um todo. As telas que consomem `rentals` (`home_tab.dart`, `active_tab.dart`, `report_tab.dart`, `catalog_tab.dart`, `end_rental_dialog.dart`, `new_rental_sheet.dart`, `pix_qr_sheet.dart`) continuam 100% em `AppState`, sem nenhuma mudança de código nelas.
- Mover a lógica de negócio de locação (`submitNew`, `extendActive`, `cancelActive`, `confirmEnd`, agendamento de notificação, cálculo de preço tempo-corrido) pro Repository — ela continua em `AppState` por enquanto. Só a posse *estrutural* da lista (`add`/remoção) muda de lugar; mutação de campo de uma `Rental` já existente (`extendActive`, `confirmEnd`/`Rental.finish`) continua operando direto no objeto, como hoje — `Rental` é mutável por design (ver doc em `lib/domain/models/rental.dart`), então isso funciona sem mudança mesmo com a lista vindo do Repository.
- Persistência — locações nunca foram persistidas (mesma situação de `Toy`), esta spec não muda isso.
- Qualquer mudança de comportamento visível.

## Cenários de usuário

Paridade total — nenhum comportamento novo, é reorganização estrutural:

1. Dado o app recém-aberto, quando qualquer tela lê `rentals`/`activeRentals`/`reportFiltered`/etc. via `AppState`, então os dados são idênticos aos de hoje (mesmo seed: `a1`–`a3` ativas, `h1`–`h8` no histórico).
2. Dado uma nova locação criada (`submitNew`) ou cancelada (`cancelActive`), quando a lista é lida em seguida por qualquer tela, então reflete a mudança — prova de que a estrutura não duplica a lista em dois lugares.

## Critérios de aceite

- [x] `RentalRepository` (`lib/data/repositories/`) é a única fonte de verdade estrutural de `List<Rental>`: semeia os mesmos 11 registros (`a1`–`a3`, `h1`–`h8`) que `AppState._seed()` tinha, com os mesmos helpers de data relativa (`minAgo`/`dAgo`/`todayAt`). Expõe `rentals` (a lista real, mutável — não `List.unmodifiable`; ver nota no `plan.md` sobre `state.rentals[i] = ...` em `open_ended_rental_test.dart`), `add(Rental)`, `removeById(String)` — ambos notificando mudança (`ChangeNotifier`).
- [x] `AppState.rentals` vira getter proxy pro Repository. `submitNew`/`cancelActive` chamam `_rentalRepository.add(...)`/`removeById(...)` em vez de mutar a lista diretamente. Todo o resto (`activeRentals`, `doneAll`, `doneToday`, `homeTotalToday`, `recentActivity`, `reportFiltered`, `reportTotal`, `paymentBreakdown`, `toyBreakdown`, `historyList`, `toyAvailable`, `toyHasRentals`, `extendActive`, `confirmEnd`, `showPixQrStep`, `computeFinalPrice`) não muda nenhuma linha — já funcionam em cima de `rentals` (getter) ou mutam um objeto `Rental` já existente em memória.
- [x] `AppState` continua widgets/testes-compatível: `rentalRepository` é parâmetro nomeado **opcional** do construtor (mesmo padrão de `businessSettingsRepository`/`toyRepository`) — nenhum `AppState(...)` em `test/` precisou mudar, e todo teste que depende do seed (`a1`, `h1` etc.) continua vendo os mesmos dados.
- [x] `main.dart` cria **uma única instância** de `RentalRepository`, injetada em `AppState` (nenhum Cubit a consome ainda nesta fatia).
- [x] Teste novo (unit, sem `WidgetTester`) cobrindo `RentalRepository`: seed tem os IDs esperados, `add`/`removeById` mudam a lista e notificam.
- [x] `flutter analyze` limpo.
- [x] Toda a suíte de testes existente passa sem alterar nenhum assert (54 testes, todos verdes).

## Requisitos não-funcionais

- Fonte de verdade única: nenhuma cópia paralela de `List<Rental>` — todo consumidor (hoje só `AppState`, amanhã os `Cubit`s das fatias 014–016) lê da mesma instância de `Repository`.
- `RentalRepository` testável com `flutter_test` puro, sem `WidgetTester`.

## Dúvidas em aberto

Nenhuma bloqueante.
