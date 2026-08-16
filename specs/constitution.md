# Constitution — Sonho de Criança

Princípios não-negociáveis do projeto. Toda spec, plano e tarefa deve respeitar isto. Conflito com constitution = constitution vence, spec é revisado.

## Stack

- Flutter (Dart SDK ^3.12.2), Material.
- State management: `provider` (ChangeNotifier em `lib/state/`). Não introduzir Riverpod/Bloc/GetX sem atualizar esta constitution primeiro.
- Fontes: `google_fonts`. Ícones: `cupertino_icons` + assets próprios.

## Arquitetura

- `lib/models/` — dados puros (Toy, Rental), sem lógica de UI.
- `lib/state/` — `AppState` (ChangeNotifier), única fonte de verdade de estado de app.
- `lib/screens/` — telas completas (rotas).
- `lib/widgets/` — componentes reutilizáveis / dialogs / sheets.
- `lib/theme/` — cores e tema centralizados. Nunca hardcode cor solta num widget — usar `AppColors`/`AppTheme`.
- `lib/test_keys.dart` — `Key`s centralizadas para testes de widget/integration. Todo widget testável ganha chave aqui, não string solta no meio do código.

## Qualidade

- `flutter analyze` limpo antes de fechar tarefa.
- Toda feature nova ou alterada de comportamento visível ganha teste em `test/` (widget test) cobrindo o critério de aceite principal.
- Sem `print` de debug esquecido, sem TODO sem dono.

## Processo (Spec Driven Development)

1. Nenhum código de feature nova é escrito sem `specs/NNN-nome/spec.md` aprovado.
2. `spec.md` (o quê / por quê) → `plan.md` (como, arquivos afetados) → `tasks.md` (checklist ordenado) → implementação.
3. Specs não descrevem código-fonte, descrevem comportamento observável e critérios de aceite testáveis.
4. Mudança de escopo durante implementação exige atualizar `spec.md`/`plan.md` antes de continuar, não depois.

## Regra de não-quebra (zero-breakage)

Nada pode quebrar em hipótese nenhuma. Se a implementação de uma spec introduzir uma regressão (`flutter analyze` falha, teste existente quebra, comportamento antigo muda sem estar no escopo da spec):

1. Trabalho naquela spec para imediatamente. Não tentar consertar em cima do que já quebrou.
2. Marcar a task/spec como `Blocked` em `tasks.md`, descrevendo a regressão encontrada.
3. A correção é uma spec/task própria, nova, separada — nunca um remendo silencioso dentro da spec que causou o problema.
4. Só depois da regressão corrigida e verificada (`flutter analyze` limpo + suíte de testes passando) outra spec pode prosseguir sobre aquela área do código.

## Segurança (baseline)

App é 100% local hoje: sem `INTERNET` permission, sem backend, sem persistência entre sessões. Isso é o piso de segurança a manter por padrão — qualquer spec que:

- Adicione permissão nova (Android `AndroidManifest.xml` / iOS `Info.plist`) precisa justificar no `plan.md` por que é mínima e necessária.
- Adicione persistência de dado pessoal (nome de criança, nome/telefone de responsável) precisa endereçar em `spec.md` onde o dado fica, por quanto tempo, e se é sensível o bastante pra precisar de criptografia em repouso.
- Envie qualquer dado pra fora do dispositivo (rede, analytics, crash reporting) é tratada como mudança de alto risco — exige revisão de segurança dedicada antes do `plan.md`, ver [specs/002-seguranca-dados/spec.md](002-seguranca-dados/spec.md).

Regra geral: dado de criança/responsável nunca trafega pra fora do aparelho sem essa revisão explícita, e nunca aparece em log.
