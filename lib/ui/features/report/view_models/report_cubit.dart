import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/rental_repository.dart';
import '../../../../data/repositories/toy_repository.dart';
import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';
import 'report_state.dart';

/// ViewModel for [ReportView] (spec 014-migracao-relatorio) — read-only:
/// filters/aggregates [RentalRepository.rentals] (cross-referenced with
/// [ToyRepository.toys] for the per-toy breakdown), recomputing whenever
/// either repository changes or [setPeriod] is called. No write path, no
/// timer, no notification — unlike the Cubits before it, this one doesn't
/// need a Use Case: it's derived reads only, not reused by another Cubit.
class ReportCubit extends Cubit<ReportState> {
  ReportCubit(RentalRepository rentalRepository, ToyRepository toyRepository)
      : _rentalRepository = rentalRepository,
        _toyRepository = toyRepository,
        super(_compute(ReportPeriod.today, rentalRepository.rentals, toyRepository.toys)) {
    _rentalRepository.addListener(_onRepositoriesChanged);
    _toyRepository.addListener(_onRepositoriesChanged);
  }

  final RentalRepository _rentalRepository;
  final ToyRepository _toyRepository;

  static const _reportWindowDays = 14;

  void _onRepositoriesChanged() => emit(_compute(state.period, _rentalRepository.rentals, _toyRepository.toys));

  void setPeriod(ReportPeriod period) => emit(_compute(period, _rentalRepository.rentals, _toyRepository.toys));

  static DateTime get _startOfDay {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _cutoffFor(ReportPeriod period) {
    switch (period) {
      case ReportPeriod.today:
        return _startOfDay;
      case ReportPeriod.week:
        return DateTime.now().subtract(const Duration(days: _reportWindowDays));
      case ReportPeriod.all:
        return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  static Toy _toyById(List<Toy> toys, String id) => toys.firstWhere((t) => t.id == id, orElse: () => toys.first);

  static ReportState _compute(ReportPeriod period, List<Rental> rentals, List<Toy> toys) {
    final cutoff = _cutoffFor(period);
    final filtered = rentals
        .where((r) => r.status == RentalStatus.done && r.endedAt != null && !r.endedAt!.isBefore(cutoff))
        .toList();

    final total = filtered.fold(0.0, (a, r) => a + r.price);

    final paymentBreakdown = <PaymentMethod, double>{
      for (final m in PaymentMethod.values) m: filtered.where((r) => r.paymentMethod == m).fold(0.0, (a, r) => a + r.price),
    };

    final toyTotals = <String, ({int count, double total})>{};
    for (final r in filtered) {
      final cur = toyTotals[r.toyId] ?? (count: 0, total: 0.0);
      toyTotals[r.toyId] = (count: cur.count + 1, total: cur.total + r.price);
    }
    final toyBreakdown = toyTotals.entries.map((e) => (toy: _toyById(toys, e.key), count: e.value.count, total: e.value.total)).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final historyList = [...filtered]..sort((a, b) => b.endedAt!.compareTo(a.endedAt!));

    return ReportState(
      period: period,
      total: total,
      filteredCount: filtered.length,
      paymentBreakdown: paymentBreakdown,
      toyBreakdown: toyBreakdown,
      historyList: historyList,
      toys: toys,
    );
  }

  @override
  Future<void> close() {
    _rentalRepository.removeListener(_onRepositoriesChanged);
    _toyRepository.removeListener(_onRepositoriesChanged);
    return super.close();
  }
}
