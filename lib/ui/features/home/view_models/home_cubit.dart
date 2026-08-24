import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/rental_repository.dart';
import '../../../../data/repositories/toy_repository.dart';
import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';
import '../../../../domain/use_cases/compute_toy_availability.dart';
import 'home_state.dart';

/// ViewModel for [HomeView] (spec 019-migracao-painel-home) — read-only,
/// cross-repository (`RentalRepository` + `ToyRepository`), same shape as
/// `ReportCubit` (014) but always "hoje" + ativas, no period filter, plus
/// a 1s ticker so "há N min" labels in the activity list stay fresh —
/// the one thing `ReportCubit` didn't need that this screen does, since
/// `AppState._ticker` used to give it that for free.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(
    ToyRepository toyRepository,
    RentalRepository rentalRepository, {
    ComputeToyAvailability computeToyAvailability = const ComputeToyAvailability(),
  })  : _toyRepository = toyRepository,
        _rentalRepository = rentalRepository,
        _computeToyAvailability = computeToyAvailability,
        super(_compute(toyRepository.toys, rentalRepository.rentals, computeToyAvailability)) {
    _toyRepository.addListener(_onChanged);
    _rentalRepository.addListener(_onChanged);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onChanged());
  }

  final ToyRepository _toyRepository;
  final RentalRepository _rentalRepository;
  final ComputeToyAvailability _computeToyAvailability;
  late final Timer _ticker;

  void _onChanged() => emit(_compute(_toyRepository.toys, _rentalRepository.rentals, _computeToyAvailability));

  static DateTime get _startOfDay {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static HomeState _compute(List<Toy> toys, List<Rental> rentals, ComputeToyAvailability computeToyAvailability) {
    final activeRentals = rentals.where((r) => r.status == RentalStatus.active).toList();
    final doneToday = rentals
        .where((r) => r.status == RentalStatus.done && r.endedAt != null && !r.endedAt!.isBefore(_startOfDay))
        .toList();
    final homeTotalToday = doneToday.fold(0.0, (a, r) => a + r.price);

    final combined = [...activeRentals, ...doneToday];
    combined.sort((a, b) {
      final ta = a.status == RentalStatus.active ? a.startedAt : a.endedAt!;
      final tb = b.status == RentalStatus.active ? b.startedAt : b.endedAt!;
      return tb.compareTo(ta);
    });

    final availableCount = toys.fold<int>(0, (a, t) => a + computeToyAvailability(t, rentals));

    return HomeState(
      recentActivity: combined.take(4).toList(),
      activeCount: activeRentals.length,
      availableCount: availableCount,
      doneTodayCount: doneToday.length,
      homeTotalToday: homeTotalToday,
      toys: toys,
    );
  }

  @override
  Future<void> close() {
    _ticker.cancel();
    _toyRepository.removeListener(_onChanged);
    _rentalRepository.removeListener(_onChanged);
    return super.close();
  }
}
