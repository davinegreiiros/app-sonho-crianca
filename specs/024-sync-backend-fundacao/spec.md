# Spec: Sync com backend — fundação (login de operador + BusinessSettings via HTTP)

Status: Implemented
Criado: 2026-09-29

Primeira fatia de comportamento visível da árvore aberta pela [022-backend-sync-fundacao](../022-backend-sync-fundacao/spec.md) (guarda-chuva, só decisão + terreno). O backend ([sonho-de-crianca-backend](../../../sonho-de-crianca-backend), spec `001-fundacao-auth-crud`) já está `Implemented` e no ar (Vercel + Atlas) — esta spec é a primeira a consumir de verdade.

## Problema

O app continua 100% local: `BusinessSettings` mora em `SharedPreferences`, `Toy`/`Rental` em SQLite (spec 020), e não existe nenhuma tela de login nem conceito de `Operator` no Flutter — apesar do backend já aceitar login e servir os três domínios via HTTP. Configurar a chave Pix num aparelho não aparece em nenhum outro; não há identidade de operador real, só o nome digitado por turno da spec 023 (`Turno.monitorName`, sem conta/senha).

## Objetivo

Existe login de operador (usuário/senha → JWT do backend) e `BusinessSettingsRepository` passa a ler/escrever no backend via HTTP em vez de `SharedPreferences` — primeira fatia vertical completa (login + 1 repository) validando login, guarda de sessão, chamada HTTP autenticada e tratamento de erro/rede antes de encarar `Toy`/`Rental` (que têm concorrência de disponibilidade, cenário 3 da 022) numa spec seguinte.

## Fora de escopo

- **`ToyRepository`/`RentalRepository` via HTTP** — fica pra spec(s) seguinte(s); mexe com concorrência de disponibilidade (cenário 3 da 022) e é bem mais arriscado que `BusinessSettings` (documento único, sem concorrência).
- **Reconciliar `Turno.monitorName` (spec 023) com `Operator` real** — o posto do monitor continua exatamente como está (nome digitado, sem conta); essa pergunta (quem loga: só o dono/admin, ou cada monitor também?) só precisa de resposta quando `Rental` migrar, porque é lá que `createdByMonitorName` e `createdByOperatorId` colidem. `BusinessSettings` só é acessado em modo administrador hoje (`admin_panel` → `BusinessSettingsView`), então esta fatia não toca o fluxo de posto.
- **Cadastro de operador pelo app** — backend v1 não tem endpoint público pra isso (decisão da spec `001` do backend, seed manual via script). Fica de fora até existir demanda.
- **Refresh token / logout por inatividade** — sessão do backend expira em 12h fixas, sem renovação silenciosa (decisão herdada da 022/001 do backend); expirar = pedir login de novo.
- **Fila offline / retry automático** — v1 do backend é online-only (decisão da 022). Sem internet = erro visível, não modo degradado.
- **Migração de dado local existente** — primeiro login não empurra o `BusinessSettings` que já está salvo local pro backend; o app passa a mostrar o que o backend tiver (mesma decisão de não migrar histórico da 022).

## Cenários de usuário

1. Dado o app aberto sem sessão, quando o operador abre Configurações do negócio (modo administrador), então é levado a uma tela de login antes de ver qualquer campo do formulário.
2. Dado credenciais corretas na tela de login, quando confirma, então a sessão (token + dados do operador) fica salva no aparelho — sobrevive a fechar/abrir o app — e ele vê o formulário de Configurações preenchido com o que está no backend.
3. Dado usuário ou senha errados, quando confirma o login, então vê mensagem de erro clara ("usuário ou senha inválidos"), sem detalhe técnico, e pode tentar de novo sem sair da tela.
4. Dado uma sessão salva e ainda válida, quando o app é reaberto, então não pede login de novo — vai direto pro formulário de Configurações.
5. Dado uma sessão com token expirado (mais de 12h), quando o operador tenta abrir Configurações ou salvar uma mudança, então é levado de volta ao login com aviso de "sessão expirada" (não um erro genérico).
6. Dado o aparelho sem internet, quando o operador tenta logar ou salvar Configurações, então vê um aviso específico de "sem conexão" — distinto do erro de credencial/sessão — sem travar a tela nem fingir que salvou.
7. Dado dois aparelhos logados com operadores diferentes, quando um salva uma nova chave Pix, então o outro vê o valor novo a próxima vez que abrir a tela de Configurações (sync via backend; não é tempo real nesta fatia — é "lê do servidor toda vez que a tela abre").
8. Dado um monitor sem conta de operador (fluxo do posto, spec 023) finalizando uma locação em Pix sem a chave configurada ainda, quando o app tentaria abrir Configurações pra ele configurar ali (atalho que já existe em `end_rental_dialog_view.dart`), então cai no mesmo login — decisão consciente desta spec: **Configurações exige operador logado sempre, não importa a tela de origem**. Consequência aceita: esse monitor não configura Pix pelo atalho; escolhe cartão/dinheiro nessa locação, ou um operador loga no aparelho antes. Não é regressão silenciosa — está registrado aqui.

## Critérios de aceite

- [x] `lib/domain/models/operator.dart` — `Operator` (id, name, username; nunca guarda senha/hash), espelhando o contrato do backend.
- [x] `lib/data/services/` — client HTTP autenticado (base URL do backend + header `Authorization: Bearer <token>` quando houver sessão; timeout curto e explícito, ex. 10s, pra nunca travar a UI esperando o backend indefinidamente).
- [x] `lib/data/repositories/auth_repository.dart` (novo) — `login(username, password)` chama `POST /api/auth/login`; guarda sessão em armazenamento seguro do aparelho (não `SharedPreferences` puro pra um JWT); expõe `currentOperator`/`isLoggedIn`/`logout()`.
- [x] Tela de login nova (`lib/ui/features/auth/`) — `LoginCubit` (estado: idle/loading/erro-credencial/erro-rede) + `LoginView` (campos usuário/senha, mensagens distintas por tipo de erro).
- [x] Entrar em Configurações do negócio sem sessão válida navega pro login primeiro; login bem-sucedido volta pro formulário.
- [x] `BusinessSettingsRepository` troca a implementação local por `GET/PUT /api/business-settings` autenticado; token expirado/401 em qualquer chamada limpa a sessão local e volta pro login com aviso — nunca erro genérico ou crash.
- [x] Nenhum JWT/senha de operador em log/`print`/`debugPrint` (constitution.md).
- [x] Teste cobrindo os cenários acima (login ok/erro-credencial/erro-rede, sessão persiste e expira, `BusinessSettings` lendo/escrevendo via HTTP) — client HTTP mockado, nenhum teste bate no backend real.
- [x] `flutter analyze` limpo.

## Requisitos não-funcionais

- Pacote HTTP e forma de armazenar o token de sessão de forma segura: decisão registrada no `plan.md` (não reabrir aqui).
- Timeout de requisição HTTP curto (ex. 10s): API fora do ar ou lenta vira aviso de rede, nunca tela travada.
- Nenhuma chamada ao backend sem TLS (herda constitution.md / 022 — o backend em produção já força HTTPS via Vercel).

## Dúvidas em aberto

Nenhuma bloqueante — resolvidas na aprovação (2026-09-29):

1. ~~Login obrigatório só em Configurações, ou app inteiro?~~ **Resolvido**: login gateia a entrada em `BusinessSettingsView` (guarda no nível da tela/rota, não por chamador) — cobre tanto o botão do admin panel quanto o atalho de `end_rental_dialog_view.dart` (cenário 8). Resto do app (posto, catálogo, locação) continua sem conta, como hoje.
2. Biblioteca de armazenamento seguro (ex. `flutter_secure_storage`) é dependência nova — de uso amplo no ecossistema Flutter, sem custo de infra; escolha final registrada no `plan.md`.
