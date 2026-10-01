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
    this.createdByMonitorName,
    this.finishedByMonitorName,
  });

  final String id;
  final String toyId;
  final String childName;
  final String guardianName;
  final String guardianPhone;
  final DateTime startedAt;

  /// `null` means this rental is "tempo corrido" (open-ended, spec 006):
  /// no fixed duration, the price is computed from elapsed time when it's
  /// finished instead of being fixed at creation. Mutable (not `final`,
  /// same reasoning as `price` below): `AppState.extendActive` (spec 008)
  /// adds minutes to an active fixed-duration rental.
  int? durationMin;

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

  /// Nome do operador real que criou a locação (spec 026-rental-via-
  /// backend: preenchido pelo `RentalRepository` com quem está logado no
  /// momento, não digitado). Não é `final`: o backend devolve a locação
  /// criada sem esse nome (só guarda `createdByOperatorId`), então
  /// `RentalRepository.addNew` o define localmente depois da resposta.
  String? createdByMonitorName;

  /// Same as [createdByMonitorName], but for whoever confirmed payment
  /// (set by [finish]).
  String? finishedByMonitorName;

  bool get isOpenEnded => durationMin == null;

  /// `true` só pra uma locação de verdade finalizada com pagamento —
  /// distinto de `status == RentalStatus.done`, que também vale pra uma
  /// locação **cancelada** (spec 026-rental-via-backend: o backend não
  /// deleta ao cancelar, marca `done` com `paymentMethod: null`). Usar
  /// este getter em qualquer soma de receita/contagem de atendimento —
  /// cancelamento nunca deve contar como receita.
  bool get isCompleted => status == RentalStatus.done && paymentMethod != null;

  Rental finish(PaymentMethod method, {String? finishedByMonitorName}) {
    status = RentalStatus.done;
    endedAt = DateTime.now();
    paymentMethod = method;
    this.finishedByMonitorName = finishedByMonitorName;
    return this;
  }
}
