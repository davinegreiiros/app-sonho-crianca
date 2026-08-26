# Spec: Backend + sync entre aparelhos — fundação (spec guarda-chuva)

Status: Implemented
Criado: 2026-08-25
Dono: análise de segurança (mesmo tratamento da spec 002 — dado sai do aparelho pela primeira vez)

Spec guarda-chuva (mesmo papel da [010-migracao-arquitetura-camadas](../010-migracao-arquitetura-camadas/spec.md) pra arquitetura em camadas): define a decisão e o contrato antes de qualquer `plan.md` de fatia sair codando. Implementação de verdade (rotas, schema Mongo, auth) mora num repositório novo (Next.js), não neste — ver "Fora de escopo".

## Problema

Hoje o app é 100% local (spec 020): cada aparelho tem seu próprio SQLite, sem noção de outro aparelho existindo, e sem noção de quem é o operador — qualquer ação parece ter sido feita por "o app". O negócio quer:

1. Múltiplos aparelhos (mais de um tablet/celular na banca) vendo o mesmo catálogo e as mesmas locações.
2. Saber **quem** fez cada ação — quem criou a locação, quem recebeu o pagamento (e por qual forma: Pix/dinheiro/cartão) — auditoria por pessoa, não só por aparelho.

Isso muda o perfil de risco que a spec [002-seguranca-dados](../002-seguranca-dados/spec.md) descreveu (100% local, zero rede, single-operador) — ela própria lista "Backend, sync em nuvem, API remota" e "autenticação de usuário" como fora de escopo e exige "nova spec de segurança dedicada" se aparecerem (regra também em `constitution.md`, seção Segurança). Esta spec é essa dedicada.

## Objetivo

Um backend (Next.js + MongoDB, repositório novo `sonho-de-crianca-backend`, pasta irmã deste) vira a fonte de verdade de `Toy`/`Rental`/`BusinessSettings`, compartilhada entre todos os aparelhos do negócio, com login por operador (não por aparelho, não por negócio) — cada ação que muda dinheiro ou estado de locação registra qual operador fez.

**v1 é online-only, deliberadamente** (decisão do dono, 2026-08-25): o app precisa de internet pra funcionar; não há fila offline nem resolução de conflito sofisticada nesta fatia. Objetivo agora é validar o comportamento básico (login, CRUD sincronizado, auditoria) com internet disponível. Offline-first (a banca sem sinal continuar operando) fica pra spec futura dedicada, só depois de validado o resto — ver "Fora de escopo".

Graças à arquitetura em camadas já migrada (specs 010–021): trocar a implementação de `ToyRepository`/`RentalRepository`/`BusinessSettingsRepository` de SQLite/`SharedPreferences` pra chamada HTTP no backend não deve tocar nenhum `Cubit`/`View` — é exatamente o ponto de ter isolado a fonte de dado atrás de Repository.

## Fora de escopo

- **Código do backend em si** — schema Mongo, rotas Next.js, deploy. Vive em `sonho-de-crianca-backend` (repo git novo, pasta irmã de `app-sonho-crianca`), com seu próprio `specs/`/`constitution.md` (mesma regra de SDD e mesma seção de Segurança herdada/adaptada desta).
- **Offline-first** — v1 exige internet. Fila de sync, resolução de conflito completa e "continuar operando sem sinal" ficam pra spec futura dedicada (depois de validar o resto funcionando online). Fica registrado aqui como decisão consciente, não omissão.
- **Multi-negócio / SaaS** — é só sync entre aparelhos do mesmo negócio, não um produto pra outras locadoras. Sem isolamento multi-tenant, sem plano de cobrança.
- **Permissões diferenciadas por papel** (admin vs. operador comum) — todo operador autenticado pode fazer tudo que o app já faz hoje; login serve pra **identidade/auditoria** ("quem fez"), não pra restringir o quê cada um pode fazer. Isso pode virar spec própria depois, se o negócio pedir.
- **Migração de dado histórico** — v1 não migra locações já feitas localmente antes do backend existir. Aparelho conectado ao backend começa do catálogo/estado que o backend tiver (ver Dúvidas em aberto/decisão abaixo).

## Modelo de ameaça (atualização da spec 002)

| Ativo | Ameaça nova (não existia na spec 002) | Vetor |
| --- | --- | --- |
| Nome de criança/responsável/telefone, chave Pix, `BusinessSettings` | Interceptação em trânsito | Chamada HTTP sem TLS, ou TLS mal configurado |
| Mesmos dados, agora em repouso fora do aparelho | Vazamento no backend | Banco Mongo mal configurado (acesso público), backup do provedor sem criptografia, credencial do backend vazada |
| Conta de operador (login individual) | Acesso indevido / repúdio ("não fui eu que recebi esse dinheiro") | Senha fraca, sem rate-limit de login, token de sessão longo demais sem expirar, operador compartilhando a própria senha com outro |
| Registro de auditoria (quem criou/recebeu pagamento) | Adulteração do log | Campo de autoria editável depois do fato, sem timestamp do servidor |
| Sync entre aparelhos | Corrupção de dado por concorrência | Dois aparelhos criam locação pro último brinquedo disponível ao mesmo tempo — sem trava, os dois "ganham" (mitigado em v1 por exigir internet + trava no servidor, não elimina 100%: ver cenário 3) |
| Endpoint da API | Abuso/DoS | API pública sem autenticação em algum endpoint, sem limite de taxa |

## Cenários de usuário

1. Dado dois aparelhos do mesmo negócio, quando um operador loga com seu usuário/senha em cada um, então cada aparelho sabe "quem está usando ele" e cada ação feita fica marcada com esse operador.
2. Dado dois aparelhos online, quando o operador A cria uma locação no aparelho A, então ela aparece no aparelho B em poucos segundos.
3. Dado dois aparelhos tentando alugar a última unidade do mesmo brinquedo quase ao mesmo tempo, quando as duas requisições chegam ao backend, então o backend aceita a primeira (ordem de chegada no servidor) e recusa a segunda com um erro claro — o aparelho perdedor mostra aviso, não perde a ação silenciosamente.
4. Dado uma locação sendo finalizada, quando o operador escolhe a forma de pagamento (Pix/dinheiro/cartão) e confirma, então o registro da locação guarda **quem** confirmou o recebimento, não só a forma de pagamento.
5. Dado o dono configura a chave Pix num aparelho, quando outro aparelho do mesmo negócio abre (logado), então já vê a mesma chave.
6. Dado o aparelho sem internet (v1), quando o operador tenta abrir o app ou fazer qualquer ação, então vê um aviso claro de "sem conexão" — não trava numa tela em branco nem finge que funcionou.

## Critérios de aceite

- [x] Decisão registrada: autenticação é **por operador** (login individual, não por aparelho nem por negócio) — todo write relevante (criar locação, estender, cancelar, finalizar/receber pagamento, editar catálogo, editar `BusinessSettings`) grava o operador responsável.
- [x] Decisão registrada: conflito de concorrência resolvido por **ordem de chegada no servidor** (timestamp do servidor no momento em que a requisição é processada, não o relógio do aparelho).
- [x] Decisão registrada: **v1 é online-only** — offline-first fica pra spec futura, depois de validar comportamento básico.
- [x] Decisão registrada: **sem migração de histórico local** — backend começa do zero.
- [x] Decisão registrada: hospedagem Vercel (Next.js) + MongoDB Atlas (tier gratuito).
- [x] Decisão registrada: repositório novo `sonho-de-crianca-backend`, pasta irmã de `app-sonho-crianca`.
- [ ] `Toy`/`Rental`/`BusinessSettings` (domain models já existentes em `lib/domain/models/`) ganham os campos de auditoria necessários (`createdByOperatorId`/`finishedByOperatorId` em `Rental`, no mínimo) — detalhado no `plan.md`.
- [ ] Nenhum dado sai do aparelho sem TLS.
- [ ] `constitution.md` (seção Segurança) e `specs/002-seguranca-dados/spec.md` atualizados pra refletir que o app deixou de ser 100% local e deixou de ser single-operador.
- [ ] Repositório novo do backend criado com sua própria `constitution.md`/`specs/README.md`, herdando o processo de SDD e a seção de Segurança (adaptada) deste projeto.

## Requisitos não-funcionais

- v1 requer internet — sem fila offline, sem sync em background. Ausência de rede é um estado de erro visível na UI, não um modo degradado silencioso.
- Toda escrita relevante carrega identidade do operador autenticado — nenhum endpoint de escrita aceita ação "anônima".
- Senha de operador nunca trafega nem fica logada em texto plano; hash no backend (bcrypt/argon2, a confirmar no `plan.md` do backend).

## Dúvidas em aberto

Não bloqueiam mais o `plan.md` (decisões acima já resolvidas) — seguem como detalhe técnico a fechar durante o `plan.md`/implementação:

1. Formato exato do login (e-mail+senha vs. usuário+senha) e duração de sessão (JWT com expiração de quanto tempo?) — a definir no `plan.md` do backend.
2. Cadastro de operador — quem cria um operador novo (o próprio dono via alguma tela de "gerenciar equipe", ou só via acesso direto ao banco por enquanto, em v1)?
3. Passo a passo de criação da conta Vercel + MongoDB Atlas — feito junto durante a execução do `plan.md`/`tasks.md` (não é decisão de spec, é tutorial de setup).
