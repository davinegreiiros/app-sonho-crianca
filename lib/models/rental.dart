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
  final int durationMin;
  final double price;
  RentalStatus status;
  DateTime? endedAt;
  PaymentMethod? paymentMethod;

  Rental finish(PaymentMethod method) {
    status = RentalStatus.done;
    endedAt = DateTime.now();
    paymentMethod = method;
    return this;
  }
}
