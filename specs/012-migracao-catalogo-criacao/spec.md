# Spec: Migração — Catálogo (criação de brinquedo)

Status: Implemented
Criado: 2026-08-23

Fatia 012 do roadmap definido em [specs/010-migracao-arquitetura-camadas](../010-migracao-arquitetura-camadas/spec.md) — escopo ajustado (ver "Aprendizado da fatia 012" na 010): só `add_toy_sheet.dart`. `catalog_tab.dart` (a grade com tickets de disponibilidade) move pra fatia 014, junto de `RentalRepository`, porque `toyAvailable()` cruza `Toy` com `Rental`.

## Problema

`lib/widgets/add_toy_sheet.dart` grava um brinquedo novo direto no `AppState`, que hoje é dono da lista `toys` inteira (em memória, sem persistência — igual já era antes desta spec). Mesmo gargalo documentado na 010: mistura tela e estado de negócio no mesmo lugar.

Diferente da 011, aqui não há um Service de persistência (brinquedos não são salvos em `SharedPreferences` — só existem em memória, semeados de `kInitialToys`), então a fatia é mais simples nesse aspecto, mas tem um consumidor cruzado real: `AppState.toys`/`toyById`/`updateToyPrice`/`updateToyBlock`/`removeToy` são lidos por `catalog_tab.dart`, `active_tab.dart`, `report_tab.dart`, `home_tab.dart`, `end_rental_dialog.dart`, `new_rental_sheet.dart` e `pix_qr_sheet.dart` — nenhum desses migra nesta fatia.

## Objetivo

`Toy` passa a ter um dono único fora do `AppState`: `ToyRepository` (`lib/data/repositories/`, sem Service — não há persistência a encapsular). `add_toy_sheet.dart` vira `ToyCatalogCubit` + `AddToySheetView` (`lib/ui/features/catalog/`). `AppState` deixa de possuir a lista de brinquedos e passa a só espelhar o `Repository`, exatamente como fez com `BusinessSettings` na 011 — nenhum dos consumidores fora de escopo muda de comportamento.

## Fora de escopo

- `catalog_tab.dart` — motivo detalhado na 010 ("Aprendizado da fatia 012"). Continua lendo `AppState.toys`/`toyAvailable`/`updateToyPrice`/`updateToyBlock`/`removeToy` (que agora são proxy pro `Repository` + `rentals` do próprio `AppState`), sem nenhuma mudança de código nela.
- `active_tab.dart`, `report_tab.dart`, `home_tab.dart`, `end_rental_dialog.dart`, `new_rental_sheet.dart`, `pix_qr_sheet.dart` — todos leem `toyById`/`toys` via `AppState`, migram na fatia 014.
- Qualquer mudança de comportamento visível, layout ou fluxo de tela.
- Persistência de `Toy` — não existe hoje (semeado de `kInitialToys` a cada boot), esta spec não introduz nenhuma.
- Use case dedicado — decisão da 010 já cobre isso: CRUD simples fala direto com o Repository.

## Cenários de usuário

Paridade total, incluindo a ponte com `AppState`:

1. Dado o catálogo com os brinquedos semeados, quando o operador abre "Adicionar brinquedo" e preenche nome/ícone/tipo/quantidade/preço/minutos/cor e salva, então o brinquedo aparece na grade do catálogo (`catalog_tab.dart`, ainda no mundo antigo) exatamente como antes.
2. Dado o formulário sem categoria escolhida, quando o operador tenta salvar, então o botão continua desabilitado — mesma validação de hoje.
3. Dado um brinquedo criado pela nova tela, quando o operador abre "Nova locação" (`new_rental_sheet.dart`, mundo antigo) ou edita preço/minutos na grade do catálogo, então o brinquedo novo aparece lá também — prova de que `AppState` e o `Cubit` nunca divergem.

## Critérios de aceite

- [x] `ToyRepository` (`lib/data/repositories/`) é a única fonte de verdade em memória de `List<Toy>`: semeia de `kInitialToys` na construção, expõe `toys` (getter síncrono, lista imutável), `addNew(...)` (gera o id, mesmo esquema `custom_<timestamp>` de hoje), `updatePrice(id, v)`, `updateBlockMinutes(id, v)`, `remove(id)` — todos notificando mudança (`ChangeNotifier`).
- [x] `ToyCatalogCubit` + `ToyCatalogState` (`equatable`) em `lib/ui/features/catalog/view_models/` — consome o `Repository`, expõe a lista de brinquedos (para reaproveitar quando `catalog_tab.dart` migrar na 014) e `addToy(...)`.
- [x] `AddToySheetView` (`lib/ui/features/catalog/views/`) substitui `lib/widgets/add_toy_sheet.dart` — mesma UI, mesmas `TestKeys`, gravando via `ToyCatalogCubit` em vez de `AppState`. Deixa de usar `context.watch<AppState>()` (a tela nunca dependeu do valor observado, só usava pra chamar `addToy` — vira `context.read<ToyCatalogCubit>()`, sem mudança observável).
- [x] `lib/widgets/add_toy_sheet.dart` removido; `lib/widgets/modal_launchers.dart` (`showAddToySheet`) aponta pra `AddToySheetView`.
- [x] `AppState.toys`, `toyById`, `updateToyPrice`, `updateToyBlock`, `addToy(...)`, `toyHasRentals`, `removeToy` continuam existindo com a mesma assinatura, agora delegando pro `ToyRepository` compartilhado — `toyAvailable` e `toyHasRentals` continuam em `AppState` sem mudança (dependem de `rentals`, que só migra na 014).
- [x] `AppState` continua widgets/testes-compatível: `toyRepository` é parâmetro nomeado **opcional** do construtor (mesmo padrão de `notifications`/`businessSettingsRepository`) — nenhum `AppState(...)` em `test/` precisou mudar.
- [x] `main.dart` cria **uma única instância** de `ToyRepository`, compartilhada entre `AppState` e `ToyCatalogCubit`.
- [x] `test/catalog_tickets_test.dart` — o teste `'AddToySheet requires a category before it can be saved'` (montava `AddToySheet` sozinho sob um `ChangeNotifierProvider<AppState>` puro) trocou esse bootstrap pra `BlocProvider<ToyCatalogCubit>` + `AddToySheetView` — mudança de *wiring* de teste (o widget não depende mais de `AppState`), não de asserts; os outros testes do arquivo (que sobem o app inteiro) não mudaram.
- [x] Teste novo (unit, sem `WidgetTester`, com `bloc_test`) cobrindo `ToyRepository`/`ToyCatalogCubit`: `addNew` gera id único e emite o novo estado; sincronia com `AppState` via mesma instância de `Repository` (mesmo padrão do teste da 011).
- [x] `flutter analyze` limpo.
- [x] Toda a suíte de testes existente passa (asserts inalterados, exceto o bootstrap do item acima) — 50 testes, todos verdes.

## Requisitos não-funcionais

- Fonte de verdade única durante a transição: nunca pode existir uma lista de `Toy` em `AppState` divergente do `ToyRepository` (cenário de usuário #3 é o teste de fumaça disso).
- `ToyCatalogCubit`/`ToyRepository` testáveis com `flutter_test` puro, sem `WidgetTester`.

## Dúvidas em aberto

Nenhuma bloqueante. Registrado no roadmap da 010: a grade do catálogo (`catalog_tab.dart`) só migra na fatia 014, junto de `RentalRepository`.
