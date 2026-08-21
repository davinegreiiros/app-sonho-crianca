# Plan: Locação em tempo corrido

Referência: [spec.md](spec.md).

## Abordagem técnica

1. `Rental.durationMin` vira nullable (`int?`). `durationMin == null` **é** a representação de "tempo corrido" — sem campo `openEnded` redundante, um único sinal de verdade. `price` também precisa ser mutável até o fim: hoje já é `final` mas só é lido depois de setado em `submitNew`; pra tempo corrido, `price` nasce `0` (placeholder, nunca exibido) e só é calculado de verdade em `confirmEnd()`. Isso implica `price` deixar de ser `final`.
2. `AppState`:
   - `RentalDraft` ganha `bool openEnded`. Quando `true`, `durationMin`/`price` do draft são ignorados pela UI (mas mantidos com os valores do preset atual só pra não deixar `null` solto em campos não-nullable do draft).
   - Novo getter `double ratePerMinute(Toy t) => t.price / t.blockMin`.
   - `submitNew()`: se `draft.openEnded`, cria `Rental` com `durationMin: null`, `price: 0`.
   - `confirmEnd()`: se `rental.durationMin == null`, calcula `elapsedMin = DateTime.now().difference(rental.startedAt).inMilliseconds / 60000`, `price = (ratePerMinute(toy) * elapsedMin * 100).round() / 100` (arredonda pra centavo, mesma convenção de `fmtMoney`) **antes** de chamar `r.finish(...)`. Locação de tempo fixo: comportamento 100% inalterado (branch nova é aditiva).
   - `statusColor`/overtime: só se aplica quando `durationMin != null` — em tempo corrido não há "estourar".
3. `NewRentalSheet`: toggle "Tempo fixo" / "Tempo corrido" (dois botões tipo os presets já existentes). Em tempo corrido, oculta a fileira de presets de minuto, o campo de minutos manual e o campo de valor — mostra em vez disso a taxa por minuto calculada (`R$ X,XX/min`), só informativa.
4. `ActiveTab`/`_ActiveCard`: quando `rental.durationMin == null`, renderiza um sub-layout diferente — cronômetro **crescente** (`elapsedMin` formatado com `fmtClock`-like, mas sem sinal de overtime) e valor estimado ao vivo (`ratePerMinute * elapsedMin`, mesmo cálculo do fim), sem `StripedProgress`. Botões "Cancelar"/"Finalizar" e a `Key` do card continuam idênticos.
5. `EndRentalDialog`: resumo (`summary`) já usa `rental.price` — pra tempo corrido isso só fica correto depois que `confirmEnd()` recalcula. Preciso mostrar o valor calculado **antes** de confirmar (o usuário vê o preço antes de escolher a forma de pagamento) — então o cálculo de preço se move pra uma função pura `AppState.computeFinalPrice(Rental)` chamada tanto pelo dialog (só leitura, pra exibir) quanto por `confirmEnd()` (pra gravar). Isso evita duplicar a fórmula.
6. `fmtMoney`/formatação: reuso do que já existe, nenhuma convenção nova.

## Arquivos afetados

- `lib/models/rental.dart` — `durationMin` nullable, `price` não mais `final`.
- `lib/state/app_state.dart` — `RentalDraft.openEnded`, `ratePerMinute`, `computeFinalPrice`, `submitNew`/`confirmEnd`/`statusColor` ajustados.
- `lib/widgets/new_rental_sheet.dart` — toggle tempo fixo/corrido, ocultar campos irrelevantes.
- `lib/screens/tabs/active_tab.dart` — variante de card pra tempo corrido.
- `lib/widgets/end_rental_dialog.dart` — usa `computeFinalPrice` pro resumo.
- `test/` — novo arquivo cobrindo cálculo de preço (unitário, sem widget), fluxo de criar/finalizar/cancelar tempo corrido (widget).

## Modelo de dados / estado

`Rental.durationMin: int?` é a mudança de schema central. Todo uso existente (`fmtClock`, `_ActiveCard`, `StripedProgress`, relatórios) foi auditado no `spec.md` — nenhum outro lugar assume `durationMin` não-nulo fora do que já foi listado ali.

## Riscos / dependências

- Maior risco de regressão das 4 specs de feature — `Rental`/`AppState` são o núcleo do app. Mitigação: nenhuma mudança de assinatura pública quebra chamada existente (tudo aditivo/nullable), suite completa roda antes de marcar `Implemented`.
- Sem dependência de outra spec.

## Alternativas consideradas

- Campo `openEnded: bool` redundante ao lado de `durationMin` nullable: descartado — dois campos podendo divergir (`openEnded: true` mas `durationMin` preenchido) é o tipo de estado inconsistente que a constitution pede pra evitar.
