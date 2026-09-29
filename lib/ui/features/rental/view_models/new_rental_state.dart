import 'package:equatable/equatable.dart';

import '../../../../domain/models/toy.dart';

/// State emitted by [NewRentalCubit] — the "Nova locação" form's own
/// draft (spec 017-migracao-nova-locacao). Deliberately **not** shared
/// with `AppState.draft`: this is ephemeral form-editing state, not
/// domain data another screen needs to see — only the `Rental` created
/// on [NewRentalCubit.submit] needs a single source of truth, and that's
/// `RentalRepository`, already shared.
class NewRentalState extends Equatable {
  const NewRentalState({
    required this.toys,
    required this.availability,
    required this.toyId,
    required this.childName,
    required this.guardianName,
    required this.guardianPhone,
    required this.durationMin,
    required this.price,
    required this.openEnded,
    required this.customRatePerMinute,
  });

  final List<Toy> toys;
  final Map<String, int> availability;

  final String toyId;
  final String childName;
  final String guardianName;
  final String guardianPhone;
  final int durationMin;
  final double price;

  /// "Tempo corrido" (spec 006): no fixed duration, price computed from
  /// elapsed time when the rental is finished.
  final bool openEnded;

  /// Operator-chosen R$/min override for a tempo-corrido rental — `null`
  /// means "use [suggestedRatePerMinute]", the pre-filled suggestion.
  final double? customRatePerMinute;

  Toy get toy => toys.firstWhere((t) => t.id == toyId, orElse: () => toys.first);

  int availabilityOf(Toy t) => availability[t.id] ?? t.qty;

  /// Price per minute the selected toy earns, derived from its own
  /// block — same formula `AppState.ratePerMinute` always used.
  double get suggestedRatePerMinute => toy.price / toy.blockMin;

  double get effectiveRatePerMinute => customRatePerMinute ?? suggestedRatePerMinute;

  bool get canSubmit => childName.trim().isNotEmpty;

  NewRentalState copyWith({
    String? toyId,
    String? childName,
    String? guardianName,
    String? guardianPhone,
    int? durationMin,
    double? price,
    bool? openEnded,
    // A distinct sentinel (not just an optional positional/named double?)
    // is needed so `copyWith` can tell "leave customRatePerMinute alone"
    // apart from "set it to null" (e.g. when the toy changes).
    Object? customRatePerMinute = _unset,
  }) {
    return NewRentalState(
      toys: toys,
      availability: availability,
      toyId: toyId ?? this.toyId,
      childName: childName ?? this.childName,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      durationMin: durationMin ?? this.durationMin,
      price: price ?? this.price,
      openEnded: openEnded ?? this.openEnded,
      customRatePerMinute: identical(customRatePerMinute, _unset) ? this.customRatePerMinute : customRatePerMinute as double?,
    );
  }

  static const _unset = Object();

  @override
  List<Object?> get props => [
        toys,
        availability,
        toyId,
        childName,
        guardianName,
        guardianPhone,
        durationMin,
        price,
        openEnded,
        customRatePerMinute,
      ];
}
