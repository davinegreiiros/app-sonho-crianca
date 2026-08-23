# Plan: Migração de arquitetura para camadas — fundação

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Esta fatia (010) não move nenhuma tela, `Cubit` ou lógica de negócio — só prepara o terreno:

1. Adicionar `flutter_bloc` e `equatable` ao `pubspec.yaml` (dependências, ainda sem uso — a primeira fatia a consumi-las é a 011).
2. Criar o esqueleto de pastas definido na `constitution.md` (`lib/data/{repositories,services}/`, `lib/domain/{models,use_cases}/`, `lib/ui/{core,features}/`). Pastas que ficam vazias por ora ganham um `.gitkeep` só pra existirem no git (git não versiona diretório vazio) — são preenchidas pelas specs 011+.
3. Mover os 3 arquivos de `lib/models/` para `lib/domain/models/` (`Toy`, `Rental`, `BusinessSettings`), sem alterar nenhuma linha de lógica — puro `git mv` + ajuste de imports.
4. Atualizar todo import que aponta pro caminho antigo (`../models/...`, `../../models/...`, `package:sonho_de_crianca/models/...`) pro novo (`.../domain/models/...`), em `lib/` e `test/`.
5. Remover `lib/models/` (pasta vazia).
6. Rodar `flutter analyze` e a suíte de testes — não pode sobrar nenhum import quebrado nem teste alterado além do path de import.

`lib/services/pix_payload.dart` e `lib/notifications/*` **não** migram aqui — isso é escopo da fatia 014 (junto com a feature de locação, único consumidor). `lib/state/app_state.dart`, `lib/screens/*`, `lib/widgets/*` também não migram aqui — só têm o import de model atualizado, permanecem onde estão até suas respectivas fatias (011–014).

## Arquivos afetados

- `pubspec.yaml` — adiciona `flutter_bloc` e `equatable` em `dependencies`.
- `lib/domain/models/toy.dart` — novo (movido de `lib/models/toy.dart`); import `../theme/app_colors.dart` vira `../../theme/app_colors.dart` (mais um nível de pasta).
- `lib/domain/models/rental.dart` — novo (movido de `lib/models/rental.dart`, sem imports relativos a ajustar).
- `lib/domain/models/business_settings.dart` — novo (movido de `lib/models/business_settings.dart`, sem imports relativos a ajustar).
- `lib/models/` — removida.
- `lib/data/repositories/.gitkeep`, `lib/data/services/.gitkeep`, `lib/domain/use_cases/.gitkeep`, `lib/ui/core/.gitkeep`, `lib/ui/features/.gitkeep` — novos, placeholders vazios pras fatias seguintes.
- `lib/state/app_state.dart` — import atualizado (`../models/*` → `../domain/models/*`).
- `lib/screens/business_settings_screen.dart` — import atualizado (`../models/*` → `../domain/models/*`).
- `lib/screens/tabs/active_tab.dart`, `home_tab.dart`, `report_tab.dart`, `catalog_tab.dart` — import atualizado (`../../models/*` → `../../domain/models/*`).
- `lib/widgets/add_toy_sheet.dart`, `category_icon.dart`, `end_rental_dialog.dart` — import atualizado (`../models/*` → `../domain/models/*`).
- `test/catalog_tickets_test.dart`, `design_v3_test.dart`, `extend_time_widget_test.dart`, `open_ended_rental_test.dart`, `rental_notifications_test.dart` — import atualizado (`package:sonho_de_crianca/models/*` → `package:sonho_de_crianca/domain/models/*`).

## Modelo de dados / estado

Nenhuma mudança de campo ou de comportamento em `Toy`, `Rental` ou `BusinessSettings` — só de localização no filesystem/import. `AppState` não é tocado além do import.

## Riscos / dependências

- Risco baixo, mas mecânico: qualquer import esquecido quebra o build imediatamente (`flutter analyze` pega na hora).
- `flutter_bloc`/`equatable` entrando sem uso ainda pode acender lint de dependência não usada em alguma ferramenta externa (não no `flutter analyze` padrão) — aceitável, é intencional, a fatia 011 já consome.
- Nenhuma dependência de outra spec não implementada.

## Alternativas consideradas

- **Não criar as pastas vazias (`data/repositories`, `data/services`, `domain/use_cases`, `ui/core`, `ui/features`) agora, só quando a 011 precisar.** Descartado: a spec 010 promete a "estrutura de pastas criada" como critério de aceite, e ter o esqueleto visível desde já deixa o roadmap concreto em vez de abstrato.
- **Migrar `AppState` inteiro nesta fatia junto com os models.** Descartado: contraria o próprio roadmap fatiado (dúvida #2 já resolvida) — misturar fundação com a primeira migração de repository/Cubit aumenta o raio de quebra de uma fatia que devia ser trivial.
