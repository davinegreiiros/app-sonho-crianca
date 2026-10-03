import '../models/rental.dart';
import '../models/turno.dart';

/// Caixa de um turno (spec 023-posto-monitor-painel): quais locações
/// contam pra ele, quanto era esperado em cada forma de pagamento e a
/// diferença entre o dinheiro contado e o esperado.
///
/// Extraído na spec 028-relatorio-dono-whatsapp: a mesma conta estava
/// escrita no fechamento de turno (`PostoSessionCubit`, 3c) e no painel
/// administrativo (`AdminPanelCubit`, 3d), e o relatório seria a terceira
/// cópia. Num lugar só, o número que o dono vê no relatório é sempre o
/// mesmo que o monitor viu ao fechar.
///
/// Regra (a que já estava implementada nos dois): locações `done` do
/// `toyId` do turno, recebidas pelo monitor do turno
/// (`finishedByMonitorName`), com `endedAt` a partir de `openedAt` — e até
/// [until], quando dado. Locação cancelada também é `done` desde a spec 026
/// (`paymentMethod == null`), por isso entra em [rentalsIn] mas nunca soma
/// em nenhuma forma de pagamento.
class ComputeTurnoCash {
  const ComputeTurnoCash();

  Iterable<Rental> rentalsIn({
    required String toyId,
    required String monitorName,
    required DateTime openedAt,
    DateTime? until,
    required List<Rental> rentals,
  }) =>
      rentals.where(
        (r) =>
            r.toyId == toyId &&
            r.status == RentalStatus.done &&
            r.endedAt != null &&
            !r.endedAt!.isBefore(openedAt) &&
            (until == null || !r.endedAt!.isAfter(until)) &&
            r.finishedByMonitorName == monitorName,
      );

  Map<PaymentMethod, double> expectedByMethod(Iterable<Rental> inTurno) => {
        for (final m in PaymentMethod.values) m: inTurno.where((r) => r.paymentMethod == m).fold(0.0, (a, r) => a + r.price),
      };

  /// `countedCash - esperado em dinheiro` de um turno já fechado; `null`
  /// enquanto o turno está aberto (ainda não houve contagem).
  double? cashDifference(Turno turno, List<Rental> rentals) {
    final closedAt = turno.closedAt;
    final counted = turno.countedCash;
    if (closedAt == null || counted == null) return null;
    final inTurno = rentalsIn(
      toyId: turno.toyId,
      monitorName: turno.monitorName,
      openedAt: turno.openedAt,
      until: closedAt,
      rentals: rentals,
    );
    return counted - expectedByMethod(inTurno)[PaymentMethod.dinheiro]!;
  }
}
