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

  Toy toyById(String id) => toys.firstWhere((t) => t.id == id, orElse: () => toys.first);

  @override
  List<Object?> get props => [recentActivity, activeCount, availableCount, doneTodayCount, homeTotalToday, toys];
}
