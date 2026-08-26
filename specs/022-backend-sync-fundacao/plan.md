# Plan: Backend + sync entre aparelhos — fundação

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

Igual em espírito à fatia 010 (arquitetura em camadas): esta fatia não migra nenhuma tela/`Cubit` do Flutter pro backend ainda — só cria o terreno (repositório novo, hospedagem, contrato de API) pras fatias seguintes (023+) consumirem, uma de cada vez, sem quebrar o app local que já funciona.

1. **Repositório novo `sonho-de-crianca-backend`** — pasta irmã de `app-sonho-crianca`, Next.js (TypeScript, App Router, só API routes — sem UI própria em v1). Estrutura espelhando a mesma arquitetura em camadas deste projeto, adaptada a backend:
   - `src/domain/models/` — `Toy`, `Rental`, `BusinessSettings`, `Operator` (tipos puros, sem lógica de framework).
   - `src/data/repositories/` — um por coleção Mongo (`ToyRepository`, `RentalRepository`, `BusinessSettingsRepository`, `OperatorRepository`), fonte única de verdade daquele domínio.
   - `src/data/services/` — cliente Mongo (conexão), hash de senha (bcrypt), assinatura/verificação de JWT.
   - `src/app/api/**/route.ts` — "controllers": só validam entrada, extraem operador autenticado do JWT, chamam Repository, formatam resposta. Sem lógica de negócio inline (mesma regra da View "burra" do Flutter, adaptada).
   - `specs/`, `constitution.md`, `specs/_templates/` — copiados/adaptados deste repo: mesma regra de SDD, mesma seção de Segurança (accrescida do que a 022 já decidiu: auth por operador, TLS obrigatório, ordem-de-chegada no servidor).
2. **Contrato de API** (rascunho nesta fatia, fechado na primeira spec do repo novo):
   - `POST /api/auth/login` — `{ username, password }` → `{ token, operator }`. Único endpoint sem auth.
   - `GET/POST /api/toys`, `PATCH /api/toys/:id`, `DELETE /api/toys/:id`.
   - `GET/POST /api/rentals`, `PATCH /api/rentals/:id/extend`, `/api/rentals/:id/cancel`, `/api/rentals/:id/finish` (grava `finishedByOperatorId` + forma de pagamento).
   - `GET/PUT /api/business-settings`.
   - Todo endpoint (exceto login) exige header `Authorization: Bearer <jwt>`; middleware comum extrai `operatorId` e rejeita (401) token ausente/inválido/expirado.
3. **Hospedagem**: MongoDB Atlas (cluster `M0` gratuito) + Vercel (deploy do repo novo, variáveis de ambiente `MONGODB_URI`/`JWT_SECRET` configuradas lá, nunca commitadas). Passo a passo guiado durante a execução das tasks (T4/T5), não é código — é conta/configuração externa.
4. **Este repo (Flutter)**: só ganha atualização de documentação nesta fatia (`constitution.md`/`specs/002-seguranca-dados/spec.md`) — nenhum `Cubit`/`Repository`/`View` muda ainda. Login de operador e troca de `ToyRepository`/`RentalRepository`/`BusinessSettingsRepository` pra HTTP são specs próprias (023+), depois do backend existir e responder de verdade — evita "codar contra uma API que ainda não existe".

## Arquivos afetados

**Neste repo (`app-sonho-crianca`):**
- `specs/constitution.md` — seção "Segurança (baseline)" atualizada: app deixa de ser "100% local hoje", passa a descrever o modelo com backend (dado sai do aparelho via TLS, autenticado por operador).
- `specs/002-seguranca-dados/spec.md` — "Fora de escopo" (linha que exclui backend/auth) ganha nota apontando pra 022 como a spec dedicada que passou a cobrir isso; "Dúvidas em aberto" sobre single-operador marcada como superada.
- `specs/README.md` — linha 022 vira `Implemented` ao final desta fatia.

**Repositório novo (`sonho-de-crianca-backend`, fora deste git):**
- Scaffold Next.js + TypeScript completo (`package.json`, `tsconfig.json`, `src/app/`, etc.).
- `constitution.md`, `specs/README.md`, `specs/_templates/` (copiados/adaptados deste repo).
- `specs/001-fundacao-auth-crud/spec.md` — primeira spec de verdade desse repo (login + CRUD de `Toy`/`Rental`/`BusinessSettings`), a escrever já seguindo o SDD do próprio repo (fora do escopo desta fatia 022 detalhar — só criar o `README.md`/`constitution.md` que a hospedam).
- `.env.example` — `MONGODB_URI`, `JWT_SECRET` (placeholders, nunca valor real commitado).
- `.gitignore` — `.env*.local`, `node_modules`.

## Modelo de dados / estado

Nenhum domain model do Flutter muda nesta fatia (fica pra 023+, quando `Rental` ganhar `createdByOperatorId`/`finishedByOperatorId`). No backend novo, os domain models (`Toy`/`Rental`/`BusinessSettings`) nascem como espelho dos existentes em `lib/domain/models/` + os campos de auditoria decididos na spec (`createdByOperatorId`, `finishedByOperatorId`, `paymentMethod`) + `Operator` novo (`id`, `name`, `username`, `passwordHash`, `createdAt`).

## Riscos / dependências

- Depende da spec 020 (persistência local) e 002 (segurança) já implementadas — ambas estão.
- Risco de escopo: é tentador já sair codando a troca de `ToyRepository` pro HTTP nesta fatia. Resistir — o repo novo precisa existir, rodar e responder (mesmo que só localmente, `next dev`) antes de qualquer código Flutter apontar pra ele, senão não dá pra testar de verdade.
- Conta MongoDB Atlas/Vercel são do usuário (e-mail pessoal) — nenhuma credencial de produção passa por este assistente além de te guiar nos cliques; segredo (`JWT_SECRET`, string de conexão) fica só nas variáveis de ambiente da Vercel/local `.env`, nunca em código ou nesta conversa em texto plano permanente.

## Alternativas consideradas

- **Monorepo (backend dentro da mesma pasta/git deste projeto).** Descartado por decisão do dono — repositório separado, deploy independente.
- **Já trocar as Repositories do Flutter pro HTTP nesta mesma fatia.** Descartado — mistura "criar fundação" com "primeira migração de consumidor", mesmo raciocínio que separou a fatia 010 das fatias 011+.
- **GraphQL em vez de REST.** Descartado — REST simples é mais direto de implementar/testar em Next.js API routes pra 4 recursos (`toys`/`rentals`/`business-settings`/`auth`), sem ganho claro de GraphQL nesse tamanho.
