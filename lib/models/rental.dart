enum PaymentMethod { pix, cartao, dinheiro }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.pix => 'Pix',
        PaymentMethod.cartao => 'Cartão',
        PaymentMethod.dinheiro => 'Dinheiro',
      };
}

enum RentalStatus { active, done }

/// A single toy rental, active or finished.
class Rental {
  Rental({
    required this.id,
    required this.toyId,
    required this.childName,
    required this.guardianName,
    this.guardianPhone = '',
    required this.startedAt,
    required this.durationMin,
    required this.price,
    required this.status,
    this.endedAt,
    this.paymentMethod,
  });

  final String id;
  final String toyId;
  final String childName;
  final String guardianName;
  final String guardianPhone;
  final DateTime startedAt;

  /// `null` means this rental is "tempo corrido" (open-ended, spec 006):
  /// no fixed duration, the price is computed from elapsed time when it's
  /// finished instead of being fixed at creation.
  final int? durationMin;

  /// Fixed at creation for a normal rental. For an open-ended one it
  /// starts at `0` (never shown — the UI reads the live estimate off
  /// [AppState.computeFinalPrice] instead) and is only set for real by
  /// `AppState.confirmEnd()`, which is why this isn't `final`.
  double price;
  RentalStatus status;
  DateTime? endedAt;
  PaymentMethod? paymentMethod;

  bool get isOpenEnded => durationMin == null;

  Rental finish(PaymentMethod method) {
    status = RentalStatus.done;
    endedAt = DateTime.now();
    paymentMethod = method;
    return this;
  }
}
