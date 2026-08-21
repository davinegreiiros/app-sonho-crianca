# Plan: Catálogo — tickets + tipo obrigatório

Referência: [spec.md](spec.md).

## Abordagem técnica

1. `ToyCategory` (enum): `eletrico, inflavel, passeio, aquatico, radiocontrole, outro`, com extensão de label pt-BR (mesmo padrão de `PaymentMethodLabel` em `rental.dart`).
2. `Toy` ganha `required this.category` — `copyWith` propaga. Os 5 seeds em `kInitialToys` recebem categoria.
3. `AddToySheet`: dropdown/seletor de categoria abaixo do nome, entra em `_valid` (obrigatório) e em `state.addToy(...)`.
4. `AppState.addToy` ganha parâmetro `required ToyCategory category`.
5. `_ToyCard` (`catalog_tab.dart`): a pílula de disponibilidade atual (`avail > 0 ? '$avail livre(s)' : 'todos em uso'`) é substituída por `_AvailabilityTickets` (novo widget privado no mesmo arquivo): renderiza `min(toy.qty, 6)` tickets serrilhados, coloridos por `toy.ink` (livre = tint sólido, em uso = tint com opacidade reduzida / borda tracejada), e se `toy.qty > 6` mostra `+N` ao final. Unidades "em uso" = `toy.qty - toyAvailable(toy)`, sempre as últimas N tickets da fileira (não precisa mapear pra locação específica).
6. Tag de tipo: nova pílula pequena acima/ao lado da de disponibilidade, com o label da categoria, reaproveitando o par tint/fg do `toy.ink` (mesmo padrão do resto do catálogo).
7. Ajustar `_contentHeight` em `catalog_tab.dart` se a nova linha de tickets não couber na altura hoje reservada — medir antes de mudar o número às cegas.

## Arquivos afetados

- `lib/models/toy.dart` — `ToyCategory` enum + label, `Toy.category`, seeds atualizados.
- `lib/state/app_state.dart` — `addToy` recebe `category`.
- `lib/widgets/add_toy_sheet.dart` — seletor de categoria, validação.
- `lib/screens/tabs/catalog_tab.dart` — `_AvailabilityTickets` novo widget, tag de tipo, ajuste de `_contentHeight` se necessário.
- `test/` — novo arquivo de widget test pro catálogo (tickets livre/misto/todos em uso/acima do limite) + teste cobrindo validação de categoria obrigatória no `AddToySheet`.

## Modelo de dados / estado

`Toy.category` é campo novo obrigatório — não nullable, não hardcoded no fallback (constitution: nada de default silencioso mascarando dado ausente). Nenhuma migração de dado persistido é necessária (app não persiste `Toy` entre sessões hoje).

## Riscos / dependências

- Depende de `001` (tokens/componentes) — já `Implemented`.
- Assets novos de ilustração ficam bloqueados (ver `spec.md`) — não bloqueiam o resto desta spec.
- Risco de quebrar altura fixa do card com a linha de tickets nova — mitigado medindo antes de mexer em `_contentHeight`.

## Alternativas consideradas

- Ticket mapeado 1:1 pra locação específica (mostrar qual criança está com qual unidade): descartado, não pedido e adiciona complexidade sem valor pro cenário descrito na spec.
