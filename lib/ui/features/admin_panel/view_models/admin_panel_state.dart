import 'package:equatable/equatable.dart';

import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';

/// One row of the "por posto e monitor" table (3d) — one per `Turno`
/// opened today. `diff` is `null` while open or while closed with no
/// divergence; only meaningful for "Dinheiro" (spec 023, decisão do
/// fechamento em `CloseShiftView`).
typedef TurnoRow = ({Toy toy, String monitorName, int locCount, double gross, bool isOpen, double? diff});

/// One entry in the read-only trilha de lançamentos (3d) — a finished
/// rental, most recent first.
typedef TrailEntry = ({Toy toy, Rental rental});

/// State emitted by `AdminPanelCubit` (spec 023-posto-monitor-painel,
/// view 3d) — totais de hoje, uma linha por turno, trilha de lançamentos.
/// Mesmo racional read-only do `ReportCubit` já existente, granularidade
/// diferente (por turno, não por toy agregado no dia inteiro).
class AdminPanelState extends Equatable {
  const AdminPanelState({
    required this.totalGrossToday,
    required this.totalLocToday,
    required this.turnRows,
    required this.trail,
  });

  const AdminPanelState.initial()
      : totalGrossToday = 0,
        totalLocToday = 0,
        turnRows = const [],
        trail = const [];

  final double totalGrossToday;
  final int totalLocToday;
  final List<TurnoRow> turnRows;
  final List<TrailEntry> trail;

  @override
  List<Object?> get props => [totalGrossToday, totalLocToday, turnRows, trail];
}
