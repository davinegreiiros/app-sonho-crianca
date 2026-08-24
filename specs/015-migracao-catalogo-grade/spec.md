# Spec: Migração — Catálogo (grade e tickets de disponibilidade)

Status: Implemented
Criado: 2026-08-23

Fatia 015 do roadmap em [specs/010-migracao-arquitetura-camadas](../010-migracao-arquitetura-camadas/spec.md) — a que ficou pendente da 012 ("Aprendizado da fatia 012"): `catalog_tab.dart` precisa cruzar `Toy` com `Rental` pra calcular disponibilidade, e agora `RentalRepository` (013) existe.

## Problema

`catalog_tab.dart` lê `state.toys`, `state.toyAvailable(toy)` (cruza `Toy.qty` com `rentals` ativas), `state.updateToyPrice`, `state.updateToyBlock` e `state.removeToy` via `AppState`. `ToyCatalogCubit` (spec 012) já existe mas só conhece `ToyRepository` — não tem como calcular disponibilidade sozinho.

## Objetivo

`ToyCatalogCubit` passa a também injetar `RentalRepository` e expor disponibilidade por brinquedo, calculada por um novo `ComputeToyAvailability` (`lib/domain/use_cases/`) — primeiro Use Case real do projeto, justificado porque é lógica cross-repository (`Toy` + `Rental`) que não é CRUD simples. `catalog_tab.dart` vira `CatalogView` (`lib/ui/features/catalog/views/`), lendo tudo do `ToyCatalogCubit`.

`AppState.toys`/`toyAvailable`/`toyHasRentals`/`updateToyPrice`/`updateToyBlock`/`removeToy` **não mudam** — `home_tab.dart` e `new_rental_sheet.dart` (fatia 016) ainda os usam. Diferente da 011/012/013, aqui não tem proxy nem remoção: os dois mundos já compartilham `ToyRepository`/`RentalRepository` desde as fatias anteriores, então não há nada a religar em `AppState`.

## Fora de escopo

- `AddToySheetView`/`ToyCatalogCubit.addToy` — já migrados na 012, ganham só a dependência nova (`RentalRepository`) sem mudar de comportamento.
- `home_tab.dart`, `new_rental_sheet.dart`, `active_tab.dart`, `end_rental_dialog.dart`, `pix_qr_sheet.dart` — continuam em `AppState`, migram na 016.
- Qualquer mudança de comportamento visível, layout ou cópia de texto.

## Cenários de usuário

Paridade total — mesmo critério das fatias anteriores:

1. Dado o catálogo com brinquedos ativos/livres misturados, quando o operador abre a aba "Brinquedos", então cada card mostra o número certo de "tickets" livres/em uso — idêntico a antes.
2. Dado uma locação nova criada em outra tela (`AppState`/`RentalRepository`, mundo antigo), quando o operador volta pro catálogo, então a disponibilidade do brinquedo correspondente já reflete a mudança — prova de que `ToyCatalogCubit` lê a mesma fonte de verdade.
3. Dado um brinquedo sem nenhuma locação (ativa ou histórica), quando o operador remove esse brinquedo, então ele some do catálogo; dado um brinquedo com locação registrada, quando o operador tenta remover, então vê o aviso de que não é possível — mesmo comportamento de hoje.
4. Dado um brinquedo com preço/duração editados na grade, quando o operador troca de aba e volta, então os valores persistem (em memória, mesma limitação de hoje) — sem regressão.

## Critérios de aceite

- [x] `ComputeToyAvailability` (`lib/domain/use_cases/`) — callable simples (`int call(Toy toy, List<Rental> rentals)`), mesma fórmula que `AppState.toyAvailable` já usa (`toy.qty - locações ativas desse toyId`).
- [x] `ToyCatalogState` ganha `availability: Map<String, int>` (toyId → disponível) e um helper `availabilityOf(Toy)`.
- [x] `ToyCatalogCubit` passa a injetar `RentalRepository` também (construtor com parâmetros nomeados normais, não `this.x` — precisa calcular o estado inicial antes do `super(...)`, mesmo motivo do `ReportCubit`). Escuta os dois repositories. Ganha `updatePrice(id, v)`, `updateBlockMinutes(id, v)`, `removeToy(id)` (guarda com `rentals.any((r) => r.toyId == id)`, mesma regra de `AppState.toyHasRentals`).
- [x] `CatalogView` (`lib/ui/features/catalog/views/`) substitui `lib/screens/tabs/catalog_tab.dart` — mesmo layout, mesmas `TestKeys`, mesma classe privada `_TicketStub` (nome idêntico — testes existentes acham ela pelo `runtimeType`), lendo/gravando via `ToyCatalogCubit`.
- [x] `home_shell.dart` aponta pra `CatalogView`.
- [x] `AppState` não muda nenhuma linha nesta fatia — `toyAvailable`/`toyHasRentals`/`updateToyPrice`/`updateToyBlock`/`removeToy` continuam ali, servindo `home_tab.dart`/`new_rental_sheet.dart` sem saber da migração.
- [x] `main.dart`: `BlocProvider<ToyCatalogCubit>` passa a injetar `RentalRepository` também (já provido desde a 013).
- [x] Teste novo (unit, sem `WidgetTester`) cobrindo `ComputeToyAvailability`/`ToyCatalogCubit`: disponibilidade correta pro seed padrão, reage a locação nova/cancelada em `RentalRepository` compartilhado.
- [x] `flutter analyze` limpo.
- [x] Toda a suíte de testes existente passa sem alterar nenhum assert (`test/catalog_tickets_test.dart` é o teste crítico aqui — cobre os tickets de disponibilidade — 71 testes, todos verdes).

## Requisitos não-funcionais

- `ComputeToyAvailability`/`ToyCatalogCubit` testáveis com `flutter_test` puro, sem `WidgetTester`.

## Dúvidas em aberto

Nenhuma bloqueante.
