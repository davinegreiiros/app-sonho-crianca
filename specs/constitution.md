# Constitution — Sonho de Criança

Princípios não-negociáveis do projeto. Toda spec, plano e tarefa deve respeitar isto. Conflito com constitution = constitution vence, spec é revisado.

## Stack

- Flutter (Dart SDK ^3.12.2), Material.
- State management: camada ViewModel usa `Cubit` (`flutter_bloc`), adotado em [specs/010-migracao-arquitetura-camadas](010-migracao-arquitetura-camadas/spec.md). `provider` continua em uso para injeção de dependência de Services/Repositories (`Provider`/`MultiProvider`); `Cubit`s são expostos pela árvore de widgets via `BlocProvider`/`MultiBlocProvider`. Não introduzir Bloc "evento puro" (event-based), Riverpod ou GetX sem atualizar esta constitution primeiro.
- Comparação de igualdade das classes de estado do `Cubit`: `equatable`. Não usar `freezed`/`built_value` sem necessidade comprovada — evita dependência de codegen/`build_runner` (ver dúvida resolvida em specs/010).
- Fontes: `google_fonts`. Ícones: `cupertino_icons` + assets próprios.

## Arquitetura

Arquitetura em camadas, adotada em [specs/010-migracao-arquitetura-camadas](010-migracao-arquitetura-camadas/spec.md) e migrada de forma incremental, fatiada por feature (backlog em `specs/README.md`). Durante a transição, a estrutura antiga (`lib/models/`, `lib/state/`, `lib/screens/`, `lib/widgets/`) coexiste com a nova nas partes do app ainda não migradas — nenhuma spec de migração pode deixar o app quebrado no meio do caminho (regra de não-quebra).

- `lib/data/services/` — classes stateless que encapsulam acesso externo (notificações locais, geração de payload PIX, etc.). Substituem `lib/notifications/*` e `lib/services/*` conforme migradas.
- `lib/data/repositories/` — um repository por domínio (`ToyRepository`, `RentalRepository`, `BusinessSettingsRepository`), fonte única de verdade de dado/negócio daquele domínio, consumindo Services. Substituem o `AppState` único conforme migrados.
- `lib/domain/models/` — modelos de domínio imutáveis (Toy, Rental, BusinessSettings), sem lógica de UI. Classes imutáveis escritas à mão, sem `freezed`/`built_value` — mesmo padrão que já existia em `lib/models/`. Substituem `lib/models/`.
- `lib/domain/use_cases/` — só quando a lógica for complexa ou reusada por mais de um `Cubit` (ex.: cálculo de valor/tempo de locação, geração de payload PIX). CRUD simples vai direto Repository → Cubit, sem use case.
- `lib/ui/core/` — widgets/tema genéricos e reutilizáveis entre features (sucessor de `lib/widgets/` + `lib/theme/` para o que não for específico de uma tela).
- `lib/ui/features/<feature>/view_models/` — um `Cubit<EstadoDaTela>` por tela/feature, injetando Repository(s)/Use Case(s) via construtor. Substituem o acesso direto e amplo ao `AppState` global.
- `lib/ui/features/<feature>/views/` — telas "burras", sucessoras de `lib/screens/*`, que só leem estado do `Cubit` (`BlocBuilder`/`BlocListener`/`BlocConsumer`) e disparam métodos dele, sem lógica de negócio inline.
- `lib/theme/` — cores e tema centralizados enquanto não migrado para `lib/ui/core/`. Nunca hardcode cor solta num widget — usar `AppColors`/`AppTheme`.
- `lib/test_keys.dart` — inalterado: `Key`s centralizadas para testes de widget/integration. Todo widget testável ganha chave aqui, não string solta no meio do código.

## Qualidade

- `flutter analyze` limpo antes de fechar tarefa.
- Toda feature nova ou alterada de comportamento visível ganha teste em `test/` (widget test) cobrindo o critério de aceite principal.
- Sem `print` de debug esquecido, sem TODO sem dono.

## Processo (Spec Driven Development)

1. Nenhum código de feature nova é escrito sem `specs/NNN-nome/spec.md` aprovado.
2. `spec.md` (o quê / por quê) → `plan.md` (como, arquivos afetados) → `tasks.md` (checklist ordenado) → implementação.
3. Specs não descrevem código-fonte, descrevem comportamento observável e critérios de aceite testáveis.
4. Mudança de escopo durante implementação exige atualizar `spec.md`/`plan.md` antes de continuar, não depois.

## Regra de não-quebra (zero-breakage)

Nada pode quebrar em hipótese nenhuma. Se a implementação de uma spec introduzir uma regressão (`flutter analyze` falha, teste existente quebra, comportamento antigo muda sem estar no escopo da spec):

1. Trabalho naquela spec para imediatamente. Não tentar consertar em cima do que já quebrou.
2. Marcar a task/spec como `Blocked` em `tasks.md`, descrevendo a regressão encontrada.
3. A correção é uma spec/task própria, nova, separada — nunca um remendo silencioso dentro da spec que causou o problema.
4. Só depois da regressão corrigida e verificada (`flutter analyze` limpo + suíte de testes passando) outra spec pode prosseguir sobre aquela área do código.

## Segurança (baseline)

App é 100% local hoje: sem `INTERNET` permission, sem backend. Dado de catálogo/locação persiste em disco (SQLite via `sqflite`, sandbox do app — spec 020-persistencia-local); `BusinessSettings` persiste via `SharedPreferences`. Persistência local (sem sair do aparelho) é o piso a manter por padrão — qualquer spec que:

- Adicione permissão nova (Android `AndroidManifest.xml` / iOS `Info.plist`) precisa justificar no `plan.md` por que é mínima e necessária.
- Adicione persistência de dado pessoal (nome de criança, nome/telefone de responsável) precisa endereçar em `spec.md` onde o dado fica, por quanto tempo, e se é sensível o bastante pra precisar de criptografia em repouso.
- Envie qualquer dado pra fora do dispositivo (rede, analytics, crash reporting) é tratada como mudança de alto risco — exige revisão de segurança dedicada antes do `plan.md`, ver [specs/002-seguranca-dados/spec.md](002-seguranca-dados/spec.md).

Regra geral: dado de criança/responsável nunca trafega pra fora do aparelho sem essa revisão explícita, e nunca aparece em log.
