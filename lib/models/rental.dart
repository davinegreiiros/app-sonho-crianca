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
    this.ratePerMinute,
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

  /// R$/min this open-ended rental charges — captured once at creation
  /// (the operator's chosen rate, defaulting to the toy's `price/blockMin`
  /// but editable, spec 006 amendment), never re-derived from the toy
  /// later. That matters: if the catalog price/duration for this toy gets
  /// edited while the rental is still running, this rental keeps earning
  /// at the rate it started with, not a rate that silently shifted under
  /// it. `null` for a fixed-duration rental (not applicable) — see
  /// `AppState.computeFinalPrice` for the fallback used when this is
  /// unset on an open-ended rental (older data, tests).
  final double? ratePerMinute;

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
