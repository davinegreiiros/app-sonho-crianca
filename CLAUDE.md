# Sonho de Criança

App Flutter de aluguel de brinquedos (Toy, Rental). Arquitetura em camadas (Repository + Cubit + View), adotada em [specs/010-migracao-arquitetura-camadas](specs/010-migracao-arquitetura-camadas/spec.md) e migrada de forma incremental — ver `specs/constitution.md` seção "Arquitetura" pra regras completas antes de tocar em qualquer camada.

## Spec Driven Development — obrigatório

Antes de codar feature nova ou mudar comportamento visível: ler [specs/README.md](specs/README.md) e [specs/constitution.md](specs/constitution.md).

Fluxo curto: `specs/NNN-nome/spec.md` (aprovado) → `plan.md` → `tasks.md` → implementação. Templates em `specs/_templates/`.

Bugfix mecânico e chore não precisam de spec.

## Estrutura

Alvo (arquitetura em camadas — usar em feature nova ou migração):

- `lib/domain/models/` — Toy, Rental, BusinessSettings (dados puros, imutáveis, sem lógica de UI).
- `lib/domain/use_cases/` — só quando lógica for complexa ou reusada por mais de um Cubit; CRUD simples vai Repository → Cubit direto.
- `lib/data/services/` — acesso externo stateless (notificações locais, payload Pix, etc.).
- `lib/data/repositories/` — um por domínio, fonte única de verdade daquele domínio, consome Services.
- `lib/ui/features/<feature>/view_models/` — `Cubit<EstadoDaTela>` (`flutter_bloc`), injeta Repository(s)/Use Case(s) via construtor; estado com `equatable`.
- `lib/ui/features/<feature>/views/` — telas "burras", só leem o Cubit (`BlocBuilder`/`BlocListener`) e disparam métodos dele.
- `lib/ui/core/` — widgets/tema genéricos reutilizáveis entre features.

Legado (ainda em uso nas partes não migradas — backlog em `specs/README.md`; não quebrar durante a transição):

- `lib/state/app_state.dart` — fonte de verdade das partes não migradas; provido via `provider`.
- `lib/screens/`, `lib/widgets/` — telas e componentes não migrados.
- `lib/notifications/`, `lib/services/` — sucedidos por `lib/data/services/` conforme migrados.

Compartilhado:

- `lib/theme/` — `AppColors`, `AppTheme`. Nunca hardcode cor solta num widget.
- `lib/test_keys.dart` — chaves centralizadas p/ testes.

## Antes de fechar tarefa

- `flutter analyze` limpo.
- Teste em `test/` cobrindo comportamento novo/alterado.
