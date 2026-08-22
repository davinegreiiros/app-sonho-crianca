# Plan: Adicionar tempo e alarme visual de tempo esgotado

Referência: `spec.md` nesta mesma pasta.

## Abordagem técnica

`Rental.durationMin` vira mutável (remove `final`) — mesmo padrão já usado em `price`, que também é mutável hoje pela mesma razão (mudar depois da criação). `AppState.extendActive` soma minutos e preço, cancela e reagenda a notificação de fim reusando `_scheduleEndNotification` (que já lê `rental.durationMin` atual). No card, o botão "+ tempo" abre um pequeno menu/row de 3 chips (5/10/15) — sem dialog novo, inline no card mesmo, próximo aos botões Cancelar/Finalizar, só quando `!openEnded`.

Alarme visual: reusa `Pulse` (`lib/widgets/animations/pulse.dart`) — já usado em `_CanhotoBadge`/ícone de tempo-corrido — aplicado a um ícone de alerta (`Icons.warning_rounded` ou similar) ao lado do relógio, visível só quando `overtime == true`. Não mexe em `StripedProgress` nem em `statusColor`, que continuam como estão.

## Arquivos afetados

- `lib/models/rental.dart` — `durationMin` deixa de ser `final`.
- `lib/state/app_state.dart` — novo método `extendActive(String rentalId, int addMinutes)`.
- `lib/screens/tabs/active_tab.dart` — `_ActiveCard`: botão "+ tempo" com 3 presets (só `!openEnded`); ícone de alarme pulsando quando `overtime`.
- `lib/test_keys.dart` — `extendRentalButton(rentalId, minutes)`.
- `test/` — teste unitário de `extendActive` (duração/preço/no-op em open-ended) + teste widget do botão "+ tempo" ausente em open-ended e presente/funcional em fixo, e do ícone de alarme aparecendo em overtime.

## Modelo de dados / estado

`Rental.durationMin: int?` deixa de ser `final`, permanece nullable (open-ended continua `null`). Nenhum campo novo. `Rental.price` já é mutável, sem mudança de tipo — `extendActive` só soma nele.

## Riscos / dependências

- Reagendar notificação depende de `RentalNotifier` (spec 005) — `_scheduleEndNotification` já cancela implicitamente? Não: precisa cancelar explicitamente antes de reagendar (`notifications.cancelRentalEnd(rentalId)` seguido de novo `scheduleRentalEnd`), senão fica notificação órfã pro horário antigo junto com a nova. Ajustar `_scheduleEndNotification` ou fazer o cancel dentro de `extendActive` antes de chamar.
- Nenhuma dependência de rede/permissão nova.
- Não mexe na notificação do SO em si (fora de escopo) — só garante que o reagendamento segue a mesma lógica já usada em `cancelActive`/`confirmEnd`.

## Alternativas consideradas

- Campo livre de minutos (input numérico) — descartado, dono do produto pediu presets rápidos (5/10/15) pra fluxo de balcão, sem teclado.
- Dialog modal de alarme ao zerar — descartado, dono do produto pediu só reforço visual não-intrusivo, card já em lista visível.
- Som/vibração no alarme — descartado, decisão registrada no spec.md.
