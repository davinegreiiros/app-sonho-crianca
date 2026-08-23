# Plan: Migração — RentalRepository (fundação)

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Mais estreito que 011/012 porque não migra nenhum consumidor — só move a *posse estrutural* da lista. `Rental` é mutável (ao contrário de `Toy`), o que simplifica: mutar um campo de uma `Rental` já na lista (`extendActive`, `Rental.finish()` em `confirmEnd`) não é uma operação estrutural, funciona igual haja ou não Repository por trás — só as duas operações que trocam *quais* objetos estão na lista (`rentals.add(...)` em `submitNew`, `rentals.removeWhere(...)` em `cancelActive`) precisam ir pro Repository.

1. **`RentalRepository extends ChangeNotifier`** — `rentals` semeado no construtor com os mesmos 11 registros e helpers (`minAgo`/`dAgo`/`todayAt`) que hoje vivem dentro de `AppState._seed()` — só copiados, sem alterar nenhum valor. `add(Rental)` e `removeById(String)` mutam `rentals` **em memória, na mesma lista** (`rentals.add(...)` / `rentals.removeWhere(...)`) e notificam.
   - **Descoberto durante a implementação**: ao contrário de `ToyRepository`/`BusinessSettingsRepository`, `rentals` **não** é `List.unmodifiable`. `test/open_ended_rental_test.dart` faz `state.rentals[index] = Rental(...)` pra "voltar no tempo" um `startedAt` (`final`, não dá pra mutar campo a campo) — comportamento que já existia antes desta spec. Envolver a lista como imutável teria sido uma mudança de comportamento não coberta pelos critérios de aceite. `rentals` continua exposta como a lista real, mutável — `add`/`removeById` são o jeito *pretendido* de mudar quem está nela, mas nada impede acesso direto (mesma situação de antes desta spec, não uma regressão de encapsulamento nova).
2. **`AppState`**: `rentalRepository` vira parâmetro nomeado opcional (mesmo padrão dos outros dois). `rentals` vira getter (`_rentalRepository.rentals`). `_seed()` perde o bloco que construía a lista de `Rental` (o Repository já nasce semeado) — mantém só a inicialização de `draft`. `submitNew`/`cancelActive` trocam a mutação direta pelas chamadas ao Repository; o restante do arquivo (leituras via `rentals.where/firstWhere/any`, mutação de campo em um `Rental` já obtido) não muda.
3. **`main.dart`**: `ChangeNotifierProvider<RentalRepository>` novo, injetado só em `AppState` — sem `BlocProvider` nesta fatia (não existe Cubit ainda).

## Arquivos afetados

- `lib/data/repositories/rental_repository.dart` — novo.
- `lib/state/app_state.dart` — `rentals` vira proxy; construtor ganha `rentalRepository` opcional; `_seed()` não monta mais a lista de `Rental`; `submitNew`/`cancelActive` chamam o Repository.
- `lib/main.dart` — provê `RentalRepository` compartilhado.
- `test/rental_repository_test.dart` — novo: seed, `add`, `removeById`, sem `WidgetTester`.

## Modelo de dados / estado

`Rental` (domain model) não muda nenhum campo nem seu design mutável — é exatamente o que já era. Nenhum `State`/`Cubit` novo nesta fatia.

## Riscos / dependências

- Risco baixo: nenhum consumidor novo, então não existe o risco de "duas fontes de verdade divergentes" que as fatias 011/012 tiveram que mitigar — só há um leitor (`AppState`) até a 014.
- Depende de 010 e 012 já implementadas (mesmo padrão de DI/proxy, `ToyRepository` como referência direta).
- Atenção mecânica: os 11 registros do seed (`a1`–`a3`, `h1`–`h8`) precisam ser copiados byte a byte — qualquer typo muda dado que dezenas de testes existentes dependem (ex.: `test/pix_flow_test.dart` usa `state.activeRentals.first`).

## Alternativas consideradas

- **Mover `submitNew`/`extendActive`/`cancelActive`/`confirmEnd` inteiros pro Repository nesta fatia.** Descartado: essas funções também orquestram notificação (`RentalNotifier`, ainda em `AppState`) e estado de UI (`showNew`, `endingId`) — misturar isso no Repository agora antecipa decisão que só faz sentido tomar na fatia 016 (quando `Service`s de notificação também migram), e infla o escopo desta fundação sem necessidade.
- **Pular direto pra "014 Relatório" sem essa fundação.** Descartado — é exatamente o problema que gerou esta spec: sem uma fonte de verdade de `Rental` fora do `AppState`, um `Cubit` de relatório não teria de onde ler sem depender do `AppState` legado.
