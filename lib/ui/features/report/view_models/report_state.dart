import 'package:equatable/equatable.dart';

import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';

/// Which window of finished rentals the report totals over — moved here
/// from `AppState` (spec 014-migracao-relatorio), nothing else reads it.
enum ReportPeriod { today, week, all }

/// State emitted by [ReportCubit] — all of it derived (filter + totals +
/// breakdowns), nothing here is stored directly.
class ReportState extends Equatable {
  const ReportState({
    required this.period,
    required this.total,
    required this.filteredCount,
    required this.paymentBreakdown,
    required this.toyBreakdown,
    required this.historyList,
    required this.toys,
  });

  final ReportPeriod period;
  final double total;
  final int filteredCount;
  final Map<PaymentMethod, double> paymentBreakdown;

  /// One row per toy that had at least one finished rental in the
  /// period, sorted by [total] descending. A plain record (not
  /// `MapEntry`) — `entry.toy`/`entry.count`/`entry.total` reads better
  /// than `entry.key`/`entry.value.count`/`entry.value.total`.
  final List<({Toy toy, int count, double total})> toyBreakdown;

  /// Finished rentals in the period, sorted by `endedAt` descending
  /// (most recent first).
  final List<Rental> historyList;

  /// Full catalog snapshot (not just the toys in [toyBreakdown]) — lets
  /// [toyById] resolve any `Rental.toyId` in [historyList], same
  /// contract `AppState.toyById` always had.
  final List<Toy> toys;

  Toy toyById(String id) => toys.firstWhere((t) => t.id == id, orElse: () => toys.first);

  @override
  List<Object?> get props => [period, total, filteredCount, paymentBreakdown, toyBreakdown, historyList, toys];
}
