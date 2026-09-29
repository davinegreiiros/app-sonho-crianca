/// A shift at one "posto" (toy station) — spec
/// 023-posto-monitor-painel. One `Turno` = one `Toy` + one monitor name,
/// from the moment they open the posto until they close it. At most one
/// open `Turno` (`closedAt == null`) per `toyId` at a time — enforced by
/// `TurnoRepository`, not here.
class Turno {
  Turno({
    required this.id,
    required this.toyId,
    required this.monitorName,
    required this.openedAt,
    this.closedAt,
    this.countedCash,
  });

  final String id;
  final String toyId;
  final String monitorName;
  final DateTime openedAt;

  /// `null` while the shift is open. Set once, by [close].
  DateTime? closedAt;

  /// Cash the monitor counted in hand at closing time — `null` until
  /// [close] is called. Only meaningful for the "Dinheiro" payment method
  /// (spec 023, `CloseShiftView`).
  double? countedCash;

  bool get isOpen => closedAt == null;

  Turno close({required double countedCash}) {
    closedAt = DateTime.now();
    this.countedCash = countedCash;
    return this;
  }
}
