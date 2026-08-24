# Plan: Persistência local (SQLite)

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

`sqflite` (pacote `sqflite: ^2.4.1`), um único banco `sonho_de_crianca.db` com duas tabelas (`toys`, `rentals`), schema versão 1, sem migração complexa (primeiro schema, nada a migrar). `BusinessSettings` não muda — continua em `SharedPreferences`.

**Camada nova**: `AppDatabase` (`lib/data/services/app_database.dart`) abre/gerencia a única instância física do banco (lazy, `Future<Database>` cacheada) — ponto único de acesso ao arquivo. `ToyLocalService`/`RentalLocalService` (`lib/data/services/`) fazem CRUD stateless sobre suas tabelas, recebendo `AppDatabase` no construtor — mesmo papel que `BusinessSettingsLocalService` já tem hoje, sem lógica de negócio, só mapeamento linha↔domain model.

**Repositories**: `ToyRepository`/`RentalRepository` ganham:
- Construtor continua 100% síncrono, com o mesmo default em memória de hoje (`kInitialToys` pro catálogo; **lista vazia** pra `RentalRepository` — a seed de demonstração `_seedInitial()` deixa de ser o default do construtor real e vira um construtor nomeado só pra teste, ver abaixo). Isso preserva a API que ~30 arquivos de teste já usam (`ToyRepository()`, `RentalRepository()` seguidos de uso imediato).
- `Future<void> load()` — lê tudo do respectivo `LocalService`. Se a tabela estiver vazia (primeira execução real), semeia (`kInitialToys` pra toys; nada pra rentals) e persiste essa seed, então substitui o estado em memória e notifica. Mesmo formato de `BusinessSettingsRepository.load()` (idempotente, guard `_disposed`).
- Cada mutação síncrona existente (`addNew`, `updatePrice`, `updateBlockMinutes`, `remove` / `addNew`, `add`, `removeById`, `extend`, `finish`) continua mutando a lista em memória e chamando `notifyListeners()` de forma síncrona (zero mudança de assinatura pública), e adicionalmente dispara a escrita correspondente no `LocalService` via `unawaited(...)` com `try/catch` (log via `debugPrint` em caso de erro — sem crash, sem retry automático, conforme decidido no `spec.md`).

**Teste de demonstração sem tocar em ~10 arquivos de teste**: os testes que hoje dependem implicitamente da seed de 8 locações fictícias (`h1`-`h8`, `a1`-`a3` — ex. `test/home_cubit_test.dart`, `test/report_cubit_test.dart`) passam a construir via `RentalRepository.withDemoSeed()` (construtor nomeado, mesmo corpo que `_seedInitial()` já tinha) em vez de `RentalRepository()`. `RentalRepository()` (default) começa vazio — é o que o app real usa. Isso é a única mudança de "wiring" que toca múltiplos arquivos de teste nesta spec.

**Boot sem flicker**: `main.dart` deixa de depender do `load()` disparado dentro do construtor de `AppState` (`app_state.dart:72`) — isso é removido de lá. Em vez disso, `main()` faz:
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final businessSettingsRepository = BusinessSettingsRepository();
  final toyRepository = ToyRepository();
  final rentalRepository = RentalRepository();
  await Future.wait([
    businessSettingsRepository.load(),
    toyRepository.load(),
    rentalRepository.load(),
  ]);
  runApp(SonhoDeCriancaApp(
    businessSettingsRepository: businessSettingsRepository,
    toyRepository: toyRepository,
    rentalRepository: rentalRepository,
  ));
}
```
`SonhoDeCriancaApp` passa a receber as três instâncias já carregadas via construtor em vez de criá-las dentro do `MultiProvider` — o `ChangeNotifierProvider.value` substitui o `ChangeNotifierProvider(create: ...)` pra esses três (não muda o resto da árvore de providers/Cubits).

**Testes de `LocalService`**: `sqflite` não roda em `flutter test` puro (depende de platform channel). Dev dependency `sqflite_common_ffi`, com `databaseFactory = databaseFactoryFfi` setado no `setUpAll` dos testes novos — banco real em arquivo temporário (ou `inMemoryDatabasePath`), sem mock/fake — cobre o SQL de verdade.

## Arquivos afetados

- `lib/data/services/app_database.dart` — novo. Abre o banco, `onCreate` cria `toys`/`rentals`.
- `lib/data/services/toy_local_service.dart` — novo. `Future<List<Toy>> loadAll()`, `Future<void> upsert(Toy)`, `Future<void> delete(String id)`.
- `lib/data/services/rental_local_service.dart` — novo. `Future<List<Rental>> loadAll()`, `Future<void> upsert(Rental)`, `Future<void> delete(String id)`.
- `lib/data/repositories/toy_repository.dart` — `load()`, persistência otimista nas mutações existentes.
- `lib/data/repositories/rental_repository.dart` — `load()`, persistência otimista nas mutações existentes; `_seedInitial()` volta a ser usado só por `RentalRepository.withDemoSeed()` (construtor nomeado, novo); construtor default passa a ser lista vazia.
- `lib/state/app_state.dart` — remove a chamada a `_businessSettingsRepository.load()` do construtor (linha 72); nenhuma outra mudança (continua recebendo os Repositories já carregados via construtor, como hoje).
- `lib/main.dart` — `main()` assíncrono, `await` dos três `load()` antes de `runApp`; `SonhoDeCriancaApp` recebe as instâncias prontas via construtor.
- `pubspec.yaml` — `sqflite` em `dependencies`; `sqflite_common_ffi` em `dev_dependencies`.
- `specs/constitution.md` — seção "Segurança (baseline)": atualiza a frase "sem persistência entre sessões" pra refletir que dado local agora persiste em SQLite na sandbox do app, sem sair do aparelho.
- `test/data/app_database_test.dart`, `test/data/toy_local_service_test.dart`, `test/data/rental_local_service_test.dart` — novos, usando `sqflite_common_ffi`.
- `test/toy_repository_test.dart`, `test/rental_repository_test.dart` — cobertura de `load()` (hidrata do `LocalService`, semeia só na primeira vez).
- Arquivos de teste que hoje dependem da seed de demonstração de `RentalRepository()` (`test/home_cubit_test.dart`, `test/report_cubit_test.dart`, e outros a identificar por `grep` durante a implementação) — trocam pra `RentalRepository.withDemoSeed()`. Nenhum assert muda.

## Modelo de dados / estado

Tabela `toys` (mapeia `Toy` 1:1):

| coluna | tipo SQLite | de/pra `Toy` |
|---|---|---|
| `id` | `TEXT PRIMARY KEY` | `id` |
| `name` | `TEXT` | `name` |
| `qty` | `INTEGER` | `qty` |
| `block_min` | `INTEGER` | `blockMin` |
| `price` | `REAL` | `price` |
| `ink` | `TEXT` | `ink.name` / `ToyInk.values.byName(...)` |
| `image_key` | `TEXT` | `imageKey` |
| `category` | `TEXT` | `category.name` / `ToyCategory.values.byName(...)` |

Tabela `rentals` (mapeia `Rental` 1:1):

| coluna | tipo SQLite | de/pra `Rental` |
|---|---|---|
| `id` | `TEXT PRIMARY KEY` | `id` |
| `toy_id` | `TEXT` | `toyId` |
| `child_name` | `TEXT` | `childName` |
| `guardian_name` | `TEXT` | `guardianName` |
| `guardian_phone` | `TEXT` | `guardianPhone` |
| `started_at` | `INTEGER` | `startedAt.millisecondsSinceEpoch` |
| `duration_min` | `INTEGER NULL` | `durationMin` |
| `rate_per_minute` | `REAL NULL` | `ratePerMinute` |
| `price` | `REAL` | `price` |
| `status` | `TEXT` | `status.name` |
| `ended_at` | `INTEGER NULL` | `endedAt?.millisecondsSinceEpoch` |
| `payment_method` | `TEXT NULL` | `paymentMethod?.name` |

Sem FK declarada entre `rentals.toy_id` e `toys.id` — uma locação histórica de um brinquedo customizado depois removido do catálogo continua legível no Relatório (comportamento atual: `Rental.toyId` já pode apontar pra um `Toy` que não existe mais, `AppState.toyById`/`HomeState.toyById` usam `orElse: () => toys.first` pra esse caso). Sem índice — volume de dado de uma loja local não justifica, e o app já filtra em memória (via `RentalRepository.rentals`), não com SQL `WHERE`.

Nenhuma mudança em `Toy`/`Rental`/`BusinessSettings` como domain models — permanecem dados puros, sem método `toMap`/`fromMap` neles (mapeamento fica nos `LocalService`, não no domain model).

## Riscos / dependências

- Depende do roadmap 010-019 já concluído (Repositories como fonte única de verdade) — sem isso não haveria um ponto único pra plugar `load()`/persistência.
- Maior risco: alterar `main()` pra assíncrono e trocar `create:` por `.value` nos providers — é mudança estrutural em `main.dart`, mas mecânica (mesmo padrão Flutter/`provider` documentado pra "instância já pronta").
- `unawaited` + `try/catch` na escrita em background: erro de IO não trava o app, mas nesta spec não há retry nem sinalização visual pro operador — aceito no `spec.md` como risco residual desta fase.
- Renomear a seed de demonstração pra `RentalRepository.withDemoSeed()` toca vários arquivos de teste — mecânico (troca de chamada de construtor), sem alterar nenhum assert; ainda assim, checar cada um por `grep -rl "RentalRepository()" test/` antes de fechar a task, pra não esquecer nenhum.

## Alternativas consideradas

- **SharedPreferences + JSON** — descartada: sem dependência nova, mas degrada conforme o histórico de locações cresce (recarrega/reserializa a lista inteira a cada leitura/escrita) e não dá base pra evoluir queries do Relatório no futuro.
- **Drift** — descartada: exige `build_runner`/codegen, que a constitution já evita explicitamente (mesma razão que descartou `freezed` na spec 010).
- **Manter `load()` disparado por `AppState`** — descartada: gera flicker de boot visível pra Catálogo/Painel (hoje inofensivo só porque `BusinessSettings` tem pouco impacto visual), e amarra o bootstrap de dado novo a uma classe em extinção.
