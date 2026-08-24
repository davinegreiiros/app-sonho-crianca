import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/rental_repository.dart';
import '../../../../data/repositories/toy_repository.dart';
import '../../../../data/services/local_rental_notifier.dart';
import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';
import '../../../../domain/rental_notifier.dart';
import '../../../../domain/use_cases/schedule_rental_end_notifications.dart';
import 'active_rentals_state.dart';

/// ViewModel for [ActiveTabView]/[EndRentalDialogView]/[PixQrSheetView]
/// (spec 018-migracao-locacao-ativa-encerrar) — reads active rentals from
/// the shared [RentalRepository], mutates through
/// [RentalRepository.extend]/[RentalRepository.finish] (so `ReportCubit`/
/// `ToyCatalogCubit` find out too — see the class docs on those methods),
/// and owns its own "Finalizar locação" dialog state (not shared with
/// `AppState.endingId`/etc. — same reasoning as `NewRentalState`'s draft).
class ActiveRentalsCubit extends Cubit<ActiveRentalsState> {
  ActiveRentalsCubit(
    ToyRepository toyRepository,
    RentalRepository rentalRepository, {
    RentalNotifier? notifications,
    ScheduleRentalEndNotifications scheduleRentalEndNotifications = const ScheduleRentalEndNotifications(),
  })  : _toyRepository = toyRepository,
        _rentalRepository = rentalRepository,
        _notifications = notifications ?? LocalRentalNotifier(),
        _scheduleRentalEndNotifications = scheduleRentalEndNotifications,
        super(ActiveRentalsState(
          activeRentals: _activeOf(rentalRepository.rentals),
          endingId: null,
          endPayment: null,
          endShowPixQr: false,
          endFrozenPrice: null,
        )) {
    _rentalRepository.addListener(_onRentalsChanged);
    // Countdown/overtime displays derive their text straight from
    // `DateTime.now()` at build time — nothing about them lives in this
    // Cubit's state — so a plain per-second re-emit is what makes the
    // View rebuild and re-read the clock, same role `AppState._ticker`
    // already played for this exact screen.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onRentalsChanged());
  }

  final ToyRepository _toyRepository;
  final RentalRepository _rentalRepository;
  final RentalNotifier _notifications;
  final ScheduleRentalEndNotifications _scheduleRentalEndNotifications;
  late final Timer _ticker;

  static List<Rental> _activeOf(List<Rental> rentals) => rentals.where((r) => r.status == RentalStatus.active).toList();

  void _onRentalsChanged() => emit(state.copyWith(activeRentals: _activeOf(_rentalRepository.rentals)));

  Toy toyById(String id) => _toyRepository.toys.firstWhere((t) => t.id == id, orElse: () => _toyRepository.toys.first);

  /// Price per minute a toy earns — same formula `AppState.ratePerMinute`
  /// always used.
  double ratePerMinute(Toy t) => t.price / t.blockMin;

  /// The price a rental should charge right now — same contract
  /// `AppState.computeFinalPrice` always had (fixed price as-is, or the
  /// live/final tempo-corrido estimate).
  double computeFinalPrice(Rental r) {
    if (!r.isOpenEnded) return r.price;
    final rate = r.ratePerMinute ?? ratePerMinute(toyById(r.toyId));
    final elapsedMin = DateTime.now().difference(r.startedAt).inMilliseconds / 60000;
    final raw = rate * elapsedMin;
    return (raw * 100).round() / 100;
  }

  void _cancelNotifications(String rentalId) {
    _notifications.cancelRentalEnd(rentalId);
    _notifications.cancelRentalEndingSoon(rentalId);
  }

  /// Adds `addMinutes` to an active fixed-duration rental (spec 008),
  /// reschedules its two notifications. No-op for `isOpenEnded`.
  void extendActive(String rentalId, int addMinutes) {
    final r = _rentalRepository.rentals.firstWhere((r) => r.id == rentalId, orElse: () => _rentalRepository.rentals.first);
    if (r.isOpenEnded) return;
    final rate = r.ratePerMinute ?? ratePerMinute(toyById(r.toyId));
    final newDuration = r.durationMin! + addMinutes;
    final newPrice = ((r.price + rate * addMinutes) * 100).round() / 100;
    _rentalRepository.extend(rentalId, durationMin: newDuration, price: newPrice);
    _cancelNotifications(r.id);
    _scheduleRentalEndNotifications(r, toyById(r.toyId), _notifications);
  }

  void cancelActive(String id) {
    _cancelNotifications(id);
    _rentalRepository.removeById(id);
  }

  void openEnd(String id) => emit(state.copyWith(endingId: id, endPayment: null, endShowPixQr: false, endFrozenPrice: null));

  void closeEnd() => emit(state.copyWith(endingId: null, endPayment: null, endShowPixQr: false, endFrozenPrice: null));

  void selectPayment(PaymentMethod m) => emit(state.copyWith(endPayment: m));

  /// Switches the still-open dialog to the Pix QR step, freezing the
  /// price right now — same reasoning `AppState.showPixQrStep` documents
  /// (a tempo-corrido estimate keeps climbing every second the QR is on
  /// screen; freeze it so `confirmEnd` never charges more than the QR the
  /// customer actually scanned encoded).
  void showPixQrStep() {
    final r = state.endingRental;
    if (r == null) return;
    emit(state.copyWith(endFrozenPrice: computeFinalPrice(r), endShowPixQr: true));
  }

  /// "Trocar forma" — backs out to payment-method selection without
  /// closing the dialog.
  void hidePixQrStep() => emit(state.copyWith(endShowPixQr: false, endFrozenPrice: null));

  void confirmEnd() {
    final payment = state.endPayment;
    final id = state.endingId;
    if (payment == null || id == null) return;
    final r = _rentalRepository.rentals.firstWhere((r) => r.id == id);
    _cancelNotifications(r.id);
    // Reuse the price frozen when the Pix QR was generated, if there was
    // one — never recompute a tempo-corrido price after the QR was
    // already shown.
    _rentalRepository.finish(
      r.id,
      payment,
      finalPrice: r.isOpenEnded ? (state.endFrozenPrice ?? computeFinalPrice(r)) : null,
    );
    emit(state.copyWith(endingId: null, endPayment: null, endFrozenPrice: null));
  }

  @override
  Future<void> close() {
    _ticker.cancel();
    _rentalRepository.removeListener(_onRentalsChanged);
    return super.close();
  }
}
