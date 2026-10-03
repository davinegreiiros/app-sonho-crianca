import 'package:equatable/equatable.dart';

import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';
import '../../../../domain/models/turno.dart';

/// Which window of finished rentals the report totals over — moved here
/// from `AppState` (spec 014-migracao-relatorio), nothing else reads it.
///
/// Spec 028-relatorio-dono-whatsapp: [week] passou de "últimos 14 dias"
/// pra semana de calendário (segunda 00:00 até agora) e [month] (dia 1
/// 00:00 até agora) entrou — é como dono de negócio pensa o período.
enum ReportPeriod { today, week, month, all }

/// Quem recebeu o pagamento (`Rental.finishedByMonitorName`) — `null`
/// (encerrada fora de um posto ou dado antigo) aparece com este rótulo.
const adminMonitorLabel = 'Administrador';

/// State emitted by [ReportCubit] — all of it derived (filter + totals +
/// breakdowns), nothing here is stored directly.
class ReportState extends Equatable {
  const ReportState({
    required this.period,
    required this.now,
    required this.total,
    required this.filteredCount,
    required this.paymentBreakdown,
    required this.toyBreakdown,
    required this.monitorBreakdown,
    required this.closedTurnosCount,
    required this.cashDiffTurnos,
    required this.historyList,
    required this.toys,
  });

  final ReportPeriod period;

  /// Instante em que o estado foi calculado — o fim do período, e a data
  /// que o resumo compartilhado mostra no cabeçalho.
  final DateTime now;

  final double total;
  final int filteredCount;
  final Map<PaymentMethod, double> paymentBreakdown;

  /// One row per toy that had at least one finished rental in the
  /// period, sorted by [total] descending. A plain record (not
  /// `MapEntry`) — `entry.toy`/`entry.count`/`entry.total` reads better
  /// than `entry.key`/`entry.value.count`/`entry.value.total`.
  final List<({Toy toy, int count, double total})> toyBreakdown;

  /// Uma linha por quem recebeu pagamento no período, maior valor
  /// primeiro. Soma das linhas = [total].
  final List<({String name, int count, double total})> monitorBreakdown;

  /// Turnos fechados no período (`closedAt` dentro dele), batendo ou não.
  final int closedTurnosCount;

  /// Só os turnos fechados no período cuja contagem de dinheiro não bateu
  /// com o esperado — mesma regra do fechamento de turno
  /// (`ComputeTurnoCash`). Mais recente primeiro.
  final List<({Turno turno, Toy toy, double diff})> cashDiffTurnos;

  /// Saldo somado das diferenças de [cashDiffTurnos].
  double get cashDiffTotal => cashDiffTurnos.fold(0.0, (a, e) => a + e.diff);

  /// Finished rentals in the period, sorted by `endedAt` descending
  /// (most recent first).
  final List<Rental> historyList;

  /// Full catalog snapshot (not just the toys in [toyBreakdown]) — lets
  /// [toyById] resolve any `Rental.toyId` in [historyList], same
  /// contract `AppState.toyById` always had.
  final List<Toy> toys;

  Toy toyById(String id) => toys.firstWhere((t) => t.id == id, orElse: () => toys.first);

  @override
  List<Object?> get props => [
        period,
        now,
        total,
        filteredCount,
        paymentBreakdown,
        toyBreakdown,
        monitorBreakdown,
        closedTurnosCount,
        cashDiffTurnos,
        historyList,
        toys,
      ];
}
