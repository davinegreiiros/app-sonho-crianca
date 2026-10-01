import 'package:equatable/equatable.dart';

import '../../../../domain/models/rental.dart';

/// State emitted by [ActiveRentalsCubit] — active rentals plus the
/// "Finalizar locação" dialog's own state machine (spec
/// 018-migracao-locacao-ativa-encerrar). The dialog state is **not**
/// shared with `AppState.endingId`/etc. — same reasoning as
/// `NewRentalState`'s draft: ephemeral UI state, not domain data.
class ActiveRentalsState extends Equatable {
  const ActiveRentalsState({
    required this.activeRentals,
    required this.endingId,
    required this.endPayment,
    required this.endShowPixQr,
    required this.endFrozenPrice,
    required this.now,
  });

  final List<Rental> activeRentals;

  final String? endingId;
  final PaymentMethod? endPayment;
  final bool endShowPixQr;
  final double? endFrozenPrice;

  /// Clock snapshot from the last emit. Countdown text is derived from
  /// `DateTime.now()` at build time, but `Rental` has no value equality and
  /// the list itself doesn't change between ticks — without this field the
  /// per-second re-emit would be `==` to the previous state and `Cubit.emit`
  /// would drop it, freezing every timer on screen.
  final DateTime now;

  /// The rental the "Finalizar locação" dialog is currently open for, if
  /// any — looked up fresh from [activeRentals] each time, same as
  /// `EndRentalDialog`'s original loop.
  Rental? get endingRental {
    for (final r in activeRentals) {
      if (r.id == endingId) return r;
    }
    return null;
  }

  ActiveRentalsState copyWith({
    List<Rental>? activeRentals,
    // Distinct sentinels so `copyWith` can tell "leave alone" apart from
    // "set to null" (both `closeEnd`/`hidePixQrStep` need the latter).
    Object? endingId = _unset,
    Object? endPayment = _unset,
    bool? endShowPixQr,
    Object? endFrozenPrice = _unset,
    DateTime? now,
  }) {
    return ActiveRentalsState(
      activeRentals: activeRentals ?? this.activeRentals,
      endingId: identical(endingId, _unset) ? this.endingId : endingId as String?,
      endPayment: identical(endPayment, _unset) ? this.endPayment : endPayment as PaymentMethod?,
      endShowPixQr: endShowPixQr ?? this.endShowPixQr,
      endFrozenPrice: identical(endFrozenPrice, _unset) ? this.endFrozenPrice : endFrozenPrice as double?,
      now: now ?? this.now,
    );
  }

  static const _unset = Object();

  @override
  List<Object?> get props => [activeRentals, endingId, endPayment, endShowPixQr, endFrozenPrice, now];
}
