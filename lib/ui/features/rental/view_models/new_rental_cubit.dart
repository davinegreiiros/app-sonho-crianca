import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/rental_repository.dart';
import '../../../../data/repositories/toy_repository.dart';
import '../../../../data/services/local_rental_notifier.dart';
import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';
import '../../../../domain/rental_notifier.dart';
import '../../../../domain/use_cases/compute_toy_availability.dart';
import '../../../../domain/use_cases/schedule_rental_end_notifications.dart';
import 'new_rental_state.dart';

/// ViewModel for [NewRentalSheetView] (spec 017-migracao-nova-locacao) —
/// owns its own form draft (see [NewRentalState]'s doc for why that's
/// not shared with `AppState.draft`), writes the finished `Rental`
/// through the shared [RentalRepository] and schedules its notifications
/// via [ScheduleRentalEndNotifications] — the same Use Case
/// `AppState._scheduleEndNotification` delegates to, so the two worlds
/// never drift on what a "new rental" actually does.
class NewRentalCubit extends Cubit<NewRentalState> {
  NewRentalCubit(
    ToyRepository toyRepository,
    RentalRepository rentalRepository, {
    RentalNotifier? notifications,
    ComputeToyAvailability computeToyAvailability = const ComputeToyAvailability(),
    ScheduleRentalEndNotifications scheduleRentalEndNotifications = const ScheduleRentalEndNotifications(),
  })  : _toyRepository = toyRepository,
        _rentalRepository = rentalRepository,
        _notifications = notifications ?? LocalRentalNotifier(),
        _computeToyAvailability = computeToyAvailability,
        _scheduleRentalEndNotifications = scheduleRentalEndNotifications,
        super(_fresh(toyRepository.toys, rentalRepository.rentals, computeToyAvailability)) {
    _toyRepository.addListener(_onRepositoriesChanged);
    _rentalRepository.addListener(_onRepositoriesChanged);
  }

  final ToyRepository _toyRepository;
  final RentalRepository _rentalRepository;
  final RentalNotifier _notifications;
  final ComputeToyAvailability _computeToyAvailability;
  final ScheduleRentalEndNotifications _scheduleRentalEndNotifications;

  /// Refreshes [NewRentalState.toys]/[NewRentalState.availability] (a
  /// rental elsewhere can change what's free while this sheet is open)
  /// without touching whatever the operator has already typed.
  void _onRepositoriesChanged() {
    final toys = _toyRepository.toys;
    final availability = _availabilityFor(toys, _rentalRepository.rentals, _computeToyAvailability);
    emit(NewRentalState(
      toys: toys,
      availability: availability,
      toyId: state.toyId,
      childName: state.childName,
      guardianName: state.guardianName,
      guardianPhone: state.guardianPhone,
      durationMin: state.durationMin,
      price: state.price,
      openEnded: state.openEnded,
      customRatePerMinute: state.customRatePerMinute,
    ));
  }

  static Map<String, int> _availabilityFor(List<Toy> toys, List<Rental> rentals, ComputeToyAvailability compute) =>
      {for (final t in toys) t.id: compute(t, rentals)};

  static NewRentalState _fresh(List<Toy> toys, List<Rental> rentals, ComputeToyAvailability compute) {
    final availability = _availabilityFor(toys, rentals, compute);
    final first = toys.firstWhere((t) => (availability[t.id] ?? t.qty) > 0, orElse: () => toys.first);
    return NewRentalState(
      toys: toys,
      availability: availability,
      toyId: first.id,
      childName: '',
      guardianName: '',
      guardianPhone: '',
      durationMin: first.blockMin,
      price: first.price,
      openEnded: false,
      customRatePerMinute: null,
    );
  }

  /// Resets the form to a fresh draft — called every time the sheet
  /// opens (`modal_launchers.dart`), same as `AppState.openNew` always
  /// did for its own draft.
  void open() => emit(_fresh(_toyRepository.toys, _rentalRepository.rentals, _computeToyAvailability));

  void setToy(String toyId) {
    final t = _toyRepository.toys.firstWhere((t) => t.id == toyId, orElse: () => _toyRepository.toys.first);
    emit(state.copyWith(toyId: toyId, durationMin: t.blockMin, price: t.price, customRatePerMinute: null));
  }

  void setChildName(String v) => emit(state.copyWith(childName: v));

  void setGuardianName(String v) => emit(state.copyWith(guardianName: v));

  void setGuardianPhone(String v) => emit(state.copyWith(guardianPhone: v));

  /// Matches the original's `Math.round(price * (min / blockMin))`.
  void applyDuration(int min) {
    final t = state.toy;
    emit(state.copyWith(durationMin: min, price: (t.price * (min / t.blockMin)).round().toDouble()));
  }

  void setPrice(double v) => emit(state.copyWith(price: v));

  void setOpenEnded(bool v) => emit(state.copyWith(openEnded: v));

  void setCustomRate(double? v) => emit(state.copyWith(customRatePerMinute: v));

  Rental submit() {
    final s = state;
    final rental = _rentalRepository.addNew(
      toyId: s.toyId,
      childName: s.childName.trim(),
      guardianName: s.guardianName.trim().isEmpty ? '—' : s.guardianName.trim(),
      guardianPhone: s.guardianPhone.trim(),
      durationMin: s.openEnded ? null : s.durationMin,
      price: s.openEnded ? 0 : s.price,
      // Captured once, here — never re-derived from the toy later (see
      // the field's doc on `Rental`).
      ratePerMinute: s.openEnded ? (s.customRatePerMinute ?? s.suggestedRatePerMinute) : null,
    );
    _scheduleRentalEndNotifications(rental, s.toy, _notifications);
    return rental;
  }

  @override
  Future<void> close() {
    _toyRepository.removeListener(_onRepositoriesChanged);
    _rentalRepository.removeListener(_onRepositoriesChanged);
    return super.close();
  }
}
