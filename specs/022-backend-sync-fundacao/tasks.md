# Tasks: Backend + sync entre aparelhos — fundação

Referência: `spec.md` + `plan.md` nesta mesma pasta. Ordem importa — de cima pra baixo.

- [x] T1 — Criar `sonho-de-crianca-backend` (pasta irmã, `git init`), scaffold Next.js + TypeScript (App Router).
- [x] T2 — Estrutura de pastas (`src/domain/models`, `src/data/repositories`, `src/data/services`, `src/app/api/`), `.gitignore`, `.env.example`.
- [x] T3 — `constitution.md` + `specs/README.md` + `specs/_templates/` no repo novo, adaptados deste (SDD + seção Segurança com as decisões da 022: auth por operador, TLS obrigatório, ordem-de-chegada no servidor).
- [ ] T4 — Guia passo a passo: criar conta + cluster gratuito MongoDB Atlas, obter `MONGODB_URI`. **Em andamento** — depende de ação do usuário (conta própria).
- [ ] T5 — Guia passo a passo: criar conta Vercel, conectar ao repo novo (GitHub), configurar variáveis de ambiente (`MONGODB_URI`, `JWT_SECRET`), primeiro deploy (só o scaffold, sem rota de verdade ainda). **Bloqueado por T4** (precisa do `MONGODB_URI` primeiro) e por existir um repo remoto no GitHub (Vercel conecta a repo remoto, não só local).
- [x] T6 — Rascunho do contrato de API documentado em `specs/001-fundacao-auth-crud/spec.md` do repo novo (Draft — spec própria, criada mas não implementada aqui).
- [x] T7 — Neste repo: `constitution.md` (seção Segurança) + `specs/002-seguranca-dados/spec.md` atualizados — app deixou de ser 100% local/single-operador, referência à 022.
- [ ] T8 — `specs/README.md` (linha 022 vira `Implemented`) — só depois de T4/T5.

Marcar cada task ao concluir. Ao final, `spec.md` Status vira `Implemented` — mesmo padrão da 010 (spec de fundação, sem comportamento novo pro usuário final ainda; as fatias que entregam comportamento são as specs 023+ neste repo e as specs do repo novo).
