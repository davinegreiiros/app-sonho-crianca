import 'package:equatable/equatable.dart';

import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';

/// State emitted by [HomeCubit] — everything the "Painel do dia" derives
/// from [RentalRepository]/[ToyRepository]: always "hoje" + ativas, no
/// period filter (that's `ReportCubit`'s job).
class HomeState extends Equatable {
  const HomeState({
    required this.recentActivity,
    required this.activeCount,
    required this.availableCount,
    required this.doneTodayCount,
    required this.homeTotalToday,
    required this.toys,
    required this.now,
  });

  /// Active + finished-today rentals, most recent first, capped at 4 —
  /// same contract `AppState.recentActivity` always had.
  final List<Rental> recentActivity;

  final int activeCount;
  final int availableCount;
  final int doneTodayCount;
  final double homeTotalToday;

  /// Full catalog snapshot — lets [toyById] resolve any
  /// `Rental.toyId` in [recentActivity], same contract
  /// `AppState.toyById` always had.
  final List<Toy> toys;

  /// Clock snapshot from the last emit — keeps the 1s ticker's re-emit from
  /// being `==` to the previous state (and dropped), so "há N min" labels
  /// actually refresh. See `ActiveRentalsState.now`.
  final DateTime now;

  Toy toyById(String id) => toys.firstWhere((t) => t.id == id, orElse: () => toys.first);

  @override
  List<Object?> get props => [recentActivity, activeCount, availableCount, doneTodayCount, homeTotalToday, toys, now];
}
