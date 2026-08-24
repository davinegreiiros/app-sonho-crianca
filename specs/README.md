# Specs — Spec Driven Development

Fluxo obrigatório pra feature nova (ver [constitution.md](constitution.md)).

## Fluxo

1. Criar pasta `specs/NNN-nome-curto/` (NNN = próximo número sequencial, 3 dígitos).
2. Copiar `_templates/spec-template.md` → `specs/NNN-nome-curto/spec.md`. Preencher. Status `Draft`.
3. Revisar com o dono do produto (você). Quando aprovado, Status vira `Approved`.
4. Copiar `_templates/plan-template.md` → `plan.md` na mesma pasta. Preencher a partir do spec aprovado.
5. Copiar `_templates/tasks-template.md` → `tasks.md`. Quebrar o plan em tasks pequenas e ordenadas.
6. Implementar seguindo `tasks.md`, marcando cada task. Código só começa aqui.
7. Ao terminar: `flutter analyze` limpo, testes passando, Status do spec vira `Implemented`.

## Numeração

Pasta = `NNN-slug-curto`, ex: `001-editar-brinquedo`, `002-historico-alugueis`. Números não se repetem mesmo se uma spec for abandonada.

## Regra de ouro

Sem `spec.md` aprovado, sem código de feature. Bugfix simples e chore não precisam de spec — só feature nova ou mudança de comportamento visível.

## Backlog atual

| # | Spec | Status | Depende de |
|---|---|---|---|
| [001](001-tema-layout-parity/spec.md) | Tema e paridade de layout com o design source | Implemented | — |
| [002](002-seguranca-dados/spec.md) | Segurança e proteção de dados | Draft | — (cross-cutting, bloqueia 004/005) |
| [003](003-catalogo-tickets-tipo/spec.md) | Catálogo — tickets de disponibilidade + tipo do brinquedo | Implemented | 001 |
| [004](004-pix-qrcode/spec.md) | QR Code Pix na finalização de locação | Implemented | 002 |
| [005](005-notificacoes-locais/spec.md) | Notificações locais de fim de locação | Implemented | 002 |
| [006](006-locacao-tempo-corrido/spec.md) | Locação em tempo corrido | Implemented | — |
| [007](007-revisao-design-v3/spec.md) | Revisão de Design v3 — ícones categoria, canhoto, Pix, Configurações, tempo corrido | Implemented | 001, 003, 004, 006 |
| [008](008-extensao-tempo-alarme/spec.md) | Adicionar tempo e alarme visual de tempo esgotado | Implemented | 005, 006 |
| [009](009-notificacao-formato-aviso-previo/spec.md) | Notificação de tempo esgotado reformatada + aviso prévio de 5 min | Implemented | 005, 008 |
| [010](010-migracao-arquitetura-camadas/spec.md) | Migração de arquitetura para camadas — fundação (spec guarda-chuva) | Implemented | — |
| [011](011-migracao-configuracoes-negocio/spec.md) | Migração: Configurações do negócio (Repository + Cubit + View) | Implemented | 010 |
| [012](012-migracao-catalogo-criacao/spec.md) | Migração: Catálogo — criação de brinquedo (Repository + Cubit + View) | Implemented | 010, 011 |
| [013](013-migracao-rental-repository-fundacao/spec.md) | Migração: `RentalRepository` — fundação | Implemented | 010, 012 |
| [014](014-migracao-relatorio/spec.md) | Migração: Relatório | Implemented | 013 |
| [015](015-migracao-catalogo-grade/spec.md) | Migração: Catálogo — grade e tickets de disponibilidade | Implemented | 012, 013 |
| [016](016-migracao-servicos-locacao-fundacao/spec.md) | Migração: Serviços de locação — fundação (Pix payload + notificações) | Implemented | 013 |
| 017+ | Migração: Locação (nova/ativa/encerrar) + PIX + notificações, sub-fatiada | Planned | 016 |

Todas em `Draft` — cada uma tem "Dúvidas em aberto" que precisa de resposta sua antes de virar `Approved` e ganhar `plan.md`/`tasks.md`.
