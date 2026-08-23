# Plan: [NOME DA FEATURE]

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Como implementar, em prosa curta. Decisões de design relevantes e por quê.

## Arquivos afetados

Novo ou modificado, com papel de cada um. Ver `specs/constitution.md` seção "Arquitetura" pra onde cada tipo de arquivo mora. Se a feature ainda depende de código não migrado (`lib/state/app_state.dart`, `lib/screens/`, `lib/widgets/`), descrever aqui como a fatia evita duas fontes de verdade (ex.: strangler fig — ver `specs/011-migracao-configuracoes-negocio/plan.md` como referência).

- `lib/domain/models/...` — novo/alterado: ...
- `lib/domain/use_cases/...` — novo/alterado (só se necessário): ...
- `lib/data/services/...` — novo/alterado: ...
- `lib/data/repositories/...` — novo/alterado: ...
- `lib/ui/features/<feature>/view_models/...` — novo/alterado (Cubit + State): ...
- `lib/ui/features/<feature>/views/...` — novo/alterado: ...
- `test/...` — cobertura: ...

## Modelo de dados / estado

Mudanças em `Toy`, `Rental`, `BusinessSettings` (domain models) ou novos. Campos novos, migrações se houver persistência. Não confundir domain model (o dado) com o `State` do Cubit (o envelope que ele emite).

## Riscos / dependências

O que pode quebrar, o que depende de outra spec/feature ainda não implementada.

## Alternativas consideradas

Opção descartada e por quê (breve).
