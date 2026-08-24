# Spec: Persistência local (SQLite)

Status: Implemented
Criado: 2026-08-24

Primeira fatia do plano "pré-backend" — ver conversa em [specs/010-migracao-arquitetura-camadas](../010-migracao-arquitetura-camadas/spec.md) (roadmap de locação, concluído em 019). Resolve a lacuna mais urgente antes de qualquer plano de backend: hoje o app perde dado real ao ser fechado.

## Problema

`ToyRepository` e `RentalRepository` não persistem nada — nem localmente. `ToyRepository` reseeda de `kInitialToys` a cada boot (comentário no próprio código: *"toys aren't saved anywhere today... reseed from kInitialToys every boot"*); `RentalRepository` também parte de uma seed em memória a cada boot. Só `BusinessSettings` sobrevive a um restart (via `BusinessSettingsLocalService`/`SharedPreferences`).

Na prática: fechar o app hoje apaga o catálogo customizado (brinquedos criados à mão) e o histórico inteiro de locações — incluindo nome de criança, nome/telefone do responsável e valores cobrados. Isso inviabiliza uso real do app pelo dono do negócio (sem histórico não há relatório confiável, sem relatório confiável não há controle financeiro) e é pré-requisito de qualquer plano de backend futuro (não dá pra sincronizar o que não é nem salvo localmente).

## Objetivo

`ToyRepository` e `RentalRepository` persistem em um banco SQLite local (`sqflite`), sobrevivendo a restart do app, seguindo o mesmo padrão assíncrono já estabelecido por `BusinessSettingsRepository` (estado em memória com default síncrono na construção + `load()` assíncrono que hidrata do disco e notifica).

## Fora de escopo

- Qualquer backend/rede — este é o passo local, backend é a próxima spec.
- Criptografia de banco em nível de aplicação (ver `Requisitos não-funcionais` — decisão já endereçada, não é código desta spec além do que estiver descrito).
- Migração de schema versionada complexa (versionamento simples de schema via `onCreate`/`onUpgrade` do `sqflite` é suficiente — não há dado de produção existente pra migrar, é o primeiro schema).
- Mudar `BusinessSettings` de `SharedPreferences` pra SQLite — já funciona, não faz parte do problema.
- Qualquer mudança de comportamento visível na UI (telas continuam idênticas).

## Cenários de usuário

1. Dado um brinquedo customizado criado no Catálogo, quando o operador fecha e reabre o app, então o brinquedo customizado continua na grade (hoje ele some).
2. Dado uma locação criada/estendida/cancelada/finalizada, quando o operador fecha e reabre o app, então ela continua aparecendo no Painel do dia / Relatório com os mesmos dados (hoje ela some).
3. Dado o app instalado pela primeira vez (banco vazio), quando ele abre, então o catálogo inicial (`kInitialToys`) é semeado uma única vez e o histórico de locações começa **vazio** — sem os dados de demonstração (locações fictícias) que o app usa hoje internamente para popular Painel/Relatório/testes.
4. Dado o app já rodando (banco não vazio) e uma nova locação sendo criada bem no momento em que o app é fechado à força, quando o app reabre, então o app não trava/crasha — na pior hipótese perde só a última escrita não confirmada (sem corrupção do banco).

## Critérios de aceite

- [x] `lib/data/services/app_database.dart` (ou nome equivalente) — abre/gerencia o banco `sqflite` (schema `toys`/`rentals`), única fonte de acesso ao banco físico.
- [x] `ToyLocalService`/`RentalLocalService` em `lib/data/services/` — CRUD stateless sobre as tabelas, mesmo papel que `BusinessSettingsLocalService` já tem hoje.
- [x] `ToyRepository`/`RentalRepository` ganham `load()` assíncrono (hidrata do banco, mesmo padrão de `BusinessSettingsRepository.load()`) — construtor continua síncrono, sem quebrar a API usada por ~30 arquivos de teste.
- [x] `main.dart` espera os três `load()` (incluindo `BusinessSettingsRepository`, hoje disparado sem `await` dentro do construtor de `AppState` — deixa de depender disso) antes do primeiro frame — sem "flicker" de Catálogo/Painel vazios no boot real. `AppState` deixa de ser o gatilho de `load()`.
- [x] Toda mutação hoje síncrona nesses dois Repositories (`addNew`, `updatePrice`, `updateBlockMinutes`, `remove`, `add`, `removeById`, `extend`, `finish`) continua com a mesma assinatura pública e efeito imediato em memória (`notifyListeners()` síncrono) — persiste no banco de forma otimista em background, mesmo padrão de `BusinessSettingsRepository.update()`, mas com erro de escrita tratado (log, não silenciado, não derruba o app).
- [x] Primeira execução real (banco vazio): catálogo semeado de `kInitialToys`; histórico de locações começa vazio (dado de demonstração fica restrito a testes, não vaza pra o app real).
- [x] `constitution.md`, seção "Segurança (baseline)": atualizada — deixa de dizer "sem persistência entre sessões" como piso padrão, passa a registrar que dado local agora persiste em disco (SQLite, sandbox do app), continua sem sair do aparelho.
- [x] `flutter analyze` limpo.
- [x] Suíte de testes existente passa sem alterar nenhum assert de comportamento (ajustes de wiring/setup são aceitáveis, como em specs anteriores).
- [x] Testes novos cobrindo `ToyLocalService`/`RentalLocalService` (persistência real via `sqflite_common_ffi` em ambiente de teste) e a hidratação de `load()`. Mais um extra além do pedido: `test/data/persistence_round_trip_test.dart`, que prova os cenários 1-3 literalmente (dois "boots" reais contra o mesmo arquivo SQLite).

## Requisitos não-funcionais

- **Onde o dado fica**: banco SQLite em armazenamento privado do app (diretório padrão do `sqflite`/`getApplicationDocumentsDirectory`), sandboxed pelo SO — não é acessível por outros apps sem root/jailbreak.
- **Por quanto tempo**: indefinidamente, até o operador apagar o app ou uma feature futura de expurgo/exportação existir (fora de escopo aqui).
- **Criptografia em repouso**: não implementada nesta spec. Justificativa: dado não sai do aparelho (mantém o piso de segurança do `constitution.md`), e a sandbox do SO (iOS Data Protection / Android app sandbox) já cobre o cenário de ameaça "outro app lendo o arquivo". Cenário não coberto: aparelho roubado e desbloqueado, ou root/jailbreak — aceito como risco residual nesta fase; reavaliar se/quando a spec de backend introduzir sincronização (dado sensível cruzando rede muda a análise).
- Sem permissão de Android/iOS nova (SQLite via `sqflite` não usa `INTERNET`).

## Dúvidas em aberto

Nenhuma bloqueante — decisão de tecnologia (`sqflite`) e de comportamento de seed (catálogo sim, locações demo não) já resolvidas nesta conversa.
