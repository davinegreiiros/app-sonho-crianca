# Spec: Segurança e proteção de dados (baseline + guard-rails para as features novas)

Status: Draft
Criado: 2026-08-15
Dono: análise de segurança (revisão sênior aplicada nesta spec)

## Problema

Hoje o app é seguro por ausência de superfície: zero permissão no `AndroidManifest.xml` (nem `INTERNET`), zero chamada de rede, zero persistência entre sessões — os dados (nome de criança, nome e telefone de responsável) vivem só em `AppState` na memória e somem ao fechar o app.

As features pedidas em `003`–`006` mudam esse perfil de risco:

- **Notificações locais** (`005`) colocam nome da criança / brinquedo em texto visível na tela de bloqueio do celular — novo vetor de exposição de dado de menor de idade pra qualquer pessoa que veja o aparelho.
- **QR Code Pix** (`004`) precisa de uma chave Pix (CPF/CNPJ/telefone/e-mail/chave aleatória do dono do negócio) embutida no payload — é dado pessoal sensível do dono, não da criança, mas com impacto financeiro direto se vazar ou for adulterado.
- Ambas abrem espaço pra alguém, no futuro, querer "só salvar isso daqui" (SharedPreferences/SQLite) sem pensar em criptografia — se isso acontecer sem controle, dado de criança fica em texto plano no disco do aparelho.

Esta spec define os requisitos de segurança que `004` e `005` (e qualquer persistência futura) têm que cumprir, e serve de checklist de revisão contínua pro app inteiro.

## Objetivo

Toda feature nova que toque em dado de criança/responsável, dinheiro ou permissão de sistema passa por esta spec antes de virar `plan.md`, e o app mantém o princípio de menor privilégio: cada permissão, cada dado persistido, cada dependência nova precisa de justificativa explícita.

## Fora de escopo

- Autenticação de usuário / multi-usuário (app hoje é single-device, single-operador — não pedido).
- Backend, sync em nuvem, API remota — não existe e nenhuma spec atual pede isso. Se aparecer, é nova spec de segurança dedicada, não extensão desta.
- Compliance formal (LGPD como processo jurídico) — aqui é engenharia: minimizar coleta, minimizar exposição, minimizar retenção. Não substitui parecer jurídico se o negócio crescer.

## Modelo de ameaça (resumo)

| Ativo | Ameaça | Vetor |
| --- | --- | --- |
| Nome da criança / responsável / telefone | Exposição a terceiro não autorizado | Notificação na tela de bloqueio (`005`), print de tela, dispositivo compartilhado/roubado |
| Chave Pix do negócio | Vazamento ou adulteração | Hardcode no código-fonte / git, payload Pix malformado, log de debug |
| Valor cobrado no Pix | Fraude (QR mostra valor errado) | Bug de cálculo, payload sem CRC16 válido |
| Dependências novas (`qr_flutter`/similar, `flutter_local_notifications`) | Supply chain | Pacote comprometido/malicioso, permissão excessiva pedida pelo pacote |
| Permissões de notificação/alarme | Sobre-coleta | Pedido de permissão mais ampla que o necessário (ex: alarme exato sem precisar) |

## Requisitos

### Dado pessoal (criança/responsável)

- [ ] Nunca aparece em `print`/log/`debugPrint` em build de produção.
- [ ] Se qualquer persistência for introduzida (não é o caso hoje), campo de criança/responsável só é salvo se a feature realmente precisar sobreviver ao restart — não persistir "por via das dúvidas".
- [ ] Se persistido, PII fica em armazenamento que suporte remoção completa (o usuário consegue apagar uma locação e o dado some de verdade, não fica em backup automático do SO). No Android isso implica revisar `android:allowBackup` antes de qualquer persistência (hoje irrelevante, não há nada pra dar backup).
- [ ] Conteúdo de notificação (`005`): **decisão registrada** — mostra brinquedo + nome da criança na tela de bloqueio (ex: "Sofia · Cama Elástica — tempo esgotado"), risco aceito explicitamente pelo dono do negócio em troca de identificar a locação de cara com várias em andamento. Fica registrado aqui como exceção deliberada à recomendação padrão de minimizar PII em notificação — não é omissão, é escolha ciente. Telefone/nome do responsável seguem fora da notificação em qualquer caso.

### Chave e payload Pix

- [ ] Chave Pix do negócio nunca fica hardcoded no código-fonte nem em asset versionado no git — é configurada pelo usuário dentro do app (campo de configuração) e mantida fora do controle de versão.
- [ ] Payload Pix (BR Code / EMV) é montado 100% localmente no dispositivo — nenhuma chamada de rede/API terceira recebe valor + chave Pix pra "gerar o QR" (nunca terceirizar isso a um serviço externo).
- [ ] Payload inclui CRC16 calculado corretamente — QR com checksum errado é bug de segurança (adultera silenciosamente valor/chave sem o usuário perceber).
- [ ] QR gerado não é logado/persistido em texto — é renderizado e descartado quando a locação some da tela.

### Permissões e dependências

- [ ] Toda permissão nova (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM` ou equivalente) é a mínima necessária, pedida em runtime só quando o recurso é usado (não no boot do app), com explicação em tela antes do prompt do SO.
- [ ] Toda dependência nova (`pubspec.yaml`) é avaliada antes de entrar: mantida ativamente, sem permissão Android/iOS além do esperado pro que faz, sem telemetria embutida não documentada.
- [ ] `flutter analyze` + build continuam sem warning de permissão não usada.

### Processo

- [ ] `plan.md` de `004` e `005` referencia esta spec e lista explicitamente qual requisito acima se aplica.
- [ ] Qualquer nova feature que envie dado pra fora do aparelho (rede) é bloqueada até ter spec de segurança própria — ver regra na `constitution.md`.

## Critérios de aceite

- [ ] Checklist "Requisitos" acima 100% marcado antes de `004`/`005` saírem de `Draft` pra `Implemented`.
- [ ] Revisão de código de `004`/`005` inclui busca textual por chave Pix/PII hardcoded antes de merge (grep simples já resolve: nenhuma chave Pix ou nome de criança fixo no diff).
- [ ] `AndroidManifest.xml`/`Info.plist` revisados a cada spec que mexe em permissão — diff mostra só a permissão nova justificada, nada a mais.

## Dúvidas em aberto

- Chave Pix: vai ter uma tela de "configurações do negócio" pra cadastrar (nome do recebedor, cidade, chave Pix)? Isso não existe hoje no app — precisa entrar no escopo de `004`.
- Se algum dia este app rodar em tablet compartilhado na loja (múltiplos operadores no mesmo aparelho), isso muda o requisito de retenção — hoje assumo single-operador.
