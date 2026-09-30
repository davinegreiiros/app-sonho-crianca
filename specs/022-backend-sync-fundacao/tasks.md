# Tasks: Backend + sync entre aparelhos — fundação

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — Criar `sonho-de-crianca-backend` (pasta irmã, `git init`), scaffold Next.js + TypeScript (App Router).
- [x] T2 — Estrutura de pastas (`src/domain/models`, `src/data/repositories`, `src/data/services`, `src/app/api/`), `.gitignore`, `.env.example`.
- [x] T3 — `constitution.md` + `specs/README.md` + `specs/_templates/` no repo novo, adaptados deste (SDD + seção Segurança com as decisões da 022: auth por operador, TLS obrigatório, ordem-de-chegada no servidor).
- [x] T4 — MongoDB Atlas: projeto `sonho-crianca-mongo`, cluster `Cluster0` (M0 free), usuário `app-sonho-crianca`, Network Access `0.0.0.0/0`, `MONGODB_URI` obtido (banco `sonho_de_crianca`) e salvo em `.env.local` (repo backend, não versionado).
- [x] T5 — Repo `sonho-de-crianca-backend` criado no GitHub (`davinegreiiros/sonho-de-crianca-backend`, privado) via `gh`, push feito. Vercel conectado ao repo, `MONGODB_URI`/`JWT_SECRET` configurados nas env vars do projeto, primeiro deploy no ar (scaffold padrão do Next.js).
- [x] T6 — Rascunho do contrato de API documentado em `specs/001-fundacao-auth-crud/spec.md` do repo novo (Draft — spec própria, criada mas não implementada aqui).
- [x] T7 — Neste repo: `constitution.md` (seção Segurança) + `specs/002-seguranca-dados/spec.md` atualizados — app deixou de ser 100% local/single-operador, referência à 022.
- [x] T8 — `specs/README.md` (linha 022 vira `Implemented`).

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented` — mesmo padrão da 010 (spec de fundação, sem comportamento novo pro usuário final ainda; as fatias que entregam comportamento são as specs 023+ neste repo e as specs do repo novo).
