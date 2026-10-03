import 'dart:ui' show Rect;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/rental_repository.dart';
import '../../../../data/repositories/toy_repository.dart';
import '../../../../data/repositories/turno_repository.dart';
import '../../../../data/services/share_plus_text_sharer.dart';
import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';
import '../../../../domain/models/turno.dart';
import '../../../../domain/text_sharer.dart';
import '../../../../domain/use_cases/compute_turno_cash.dart';
import 'report_state.dart';
import 'report_summary.dart';

/// ViewModel for [ReportView] (spec 014-migracao-relatorio) — read-only:
/// filters/aggregates [RentalRepository.rentals] (cross-referenced with
/// [ToyRepository.toys] for the per-toy breakdown), recomputing whenever
/// either repository changes or [setPeriod] is called.
///
/// Spec 028-relatorio-dono-whatsapp: semana/mês de calendário, quem
/// recebeu (por monitor), caixa do período (lê [TurnoRepository], mesma
/// regra do fechamento via [ComputeTurnoCash]) e o resumo em texto
/// mandado pra fora por [TextSharer]. [clock] existe pra teste — os cortes
/// de semana/mês dependem do dia da semana.
class ReportCubit extends Cubit<ReportState> {
  ReportCubit(
    RentalRepository rentalRepository,
    ToyRepository toyRepository, {
    TurnoRepository? turnoRepository,
    TextSharer? textSharer,
    DateTime Function()? clock,
  })  : _rentalRepository = rentalRepository,
        _toyRepository = toyRepository,
        _turnoRepository = turnoRepository ?? TurnoRepository(),
        _textSharer = textSharer ?? const SharePlusTextSharer(),
        _clock = clock ?? DateTime.now,
        super(_compute(
          ReportPeriod.today,
          (clock ?? DateTime.now)(),
          rentalRepository.rentals,
          toyRepository.toys,
          turnoRepository?.turnos ?? const [],
        )) {
    _rentalRepository.addListener(_onRepositoriesChanged);
    _toyRepository.addListener(_onRepositoriesChanged);
    _turnoRepository.addListener(_onRepositoriesChanged);
  }

  final RentalRepository _rentalRepository;
  final ToyRepository _toyRepository;
  final TurnoRepository _turnoRepository;
  final TextSharer _textSharer;
  final DateTime Function() _clock;

  static const _computeTurnoCash = ComputeTurnoCash();

  void _onRepositoriesChanged() => setPeriod(state.period);

  void setPeriod(ReportPeriod period) => emit(_compute(
        period,
        _clock(),
        _rentalRepository.rentals,
        _toyRepository.toys,
        _turnoRepository.turnos,
      ));

  /// Texto do resumo do período atual (o que [shareSummary] manda).
  String summaryText() => buildReportSummary(state);

  /// Recalcula (o "agora" anda) e abre a folha de compartilhamento com o
  /// resumo. [origin]: retângulo do botão, pro popover do iPad.
  Future<void> shareSummary({Rect? origin}) {
    setPeriod(state.period);
    return _textSharer.share(summaryText(), origin: origin);
  }

  /// Início do período, em hora local. Semana começa segunda-feira.
  static DateTime cutoffFor(ReportPeriod period, DateTime now) {
    final startOfDay = DateTime(now.year, now.month, now.day);
    return switch (period) {
      ReportPeriod.today => startOfDay,
      ReportPeriod.week => DateTime(now.year, now.month, now.day - (now.weekday - DateTime.monday)),
      ReportPeriod.month => DateTime(now.year, now.month, 1),
      ReportPeriod.all => DateTime.fromMillisecondsSinceEpoch(0),
    };
  }

  static Toy _toyById(List<Toy> toys, String id) => toys.firstWhere((t) => t.id == id, orElse: () => toys.first);

  static ReportState _compute(
    ReportPeriod period,
    DateTime now,
    List<Rental> rentals,
    List<Toy> toys,
    List<Turno> turnos,
  ) {
    final cutoff = cutoffFor(period, now);
    final filtered = rentals
        .where((r) => r.isCompleted && r.endedAt != null && !r.endedAt!.isBefore(cutoff))
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

    final monitorTotals = <String, ({int count, double total})>{};
    for (final r in filtered) {
      final name = (r.finishedByMonitorName ?? '').trim().isEmpty ? adminMonitorLabel : r.finishedByMonitorName!.trim();
      final cur = monitorTotals[name] ?? (count: 0, total: 0.0);
      monitorTotals[name] = (count: cur.count + 1, total: cur.total + r.price);
    }
    final monitorBreakdown = monitorTotals.entries.map((e) => (name: e.key, count: e.value.count, total: e.value.total)).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final closedInPeriod = turnos
        .where((t) => t.closedAt != null && !t.closedAt!.isBefore(cutoff) && !t.closedAt!.isAfter(now))
        .toList()
      ..sort((a, b) => b.closedAt!.compareTo(a.closedAt!));
    final cashDiffTurnos = <({Turno turno, Toy toy, double diff})>[];
    if (toys.isNotEmpty) {
      for (final t in closedInPeriod) {
        final diff = _computeTurnoCash.cashDifference(t, rentals);
        // Centavo de arredondamento de ponto flutuante não é "caixa não bateu".
        if (diff != null && diff.abs() >= 0.005) {
          cashDiffTurnos.add((turno: t, toy: _toyById(toys, t.toyId), diff: diff));
        }
      }
    }

    final historyList = [...filtered]..sort((a, b) => b.endedAt!.compareTo(a.endedAt!));

    return ReportState(
      period: period,
      now: now,
      total: total,
      filteredCount: filtered.length,
      paymentBreakdown: paymentBreakdown,
      toyBreakdown: toyBreakdown,
      monitorBreakdown: monitorBreakdown,
      closedTurnosCount: closedInPeriod.length,
      cashDiffTurnos: cashDiffTurnos,
      historyList: historyList,
      toys: toys,
    );
  }

  @override
  Future<void> close() {
    _rentalRepository.removeListener(_onRepositoriesChanged);
    _toyRepository.removeListener(_onRepositoriesChanged);
    _turnoRepository.removeListener(_onRepositoriesChanged);
    return super.close();
  }
}
