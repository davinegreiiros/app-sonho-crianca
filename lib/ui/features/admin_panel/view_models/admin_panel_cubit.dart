import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/rental_repository.dart';
import '../../../../data/repositories/toy_repository.dart';
import '../../../../data/repositories/turno_repository.dart';
import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';
import '../../../../domain/models/turno.dart';
import 'admin_panel_state.dart';

/// ViewModel for [AdminPanelView] (3d, spec 023-posto-monitor-painel) —
/// read-only, recomputa sempre que `RentalRepository`/`ToyRepository`/
/// `TurnoRepository` mudam. Mesmo molde do `ReportCubit` já existente
/// (período fixo "hoje"), mas por turno em vez de por toy agregado.
class AdminPanelCubit extends Cubit<AdminPanelState> {
  AdminPanelCubit(
    RentalRepository rentalRepository,
    ToyRepository toyRepository,
    TurnoRepository turnoRepository,
  )   : _rentalRepository = rentalRepository,
        _toyRepository = toyRepository,
        _turnoRepository = turnoRepository,
        super(_compute(rentalRepository.rentals, toyRepository.toys, turnoRepository.turnos)) {
    _rentalRepository.addListener(_onChanged);
    _toyRepository.addListener(_onChanged);
    _turnoRepository.addListener(_onChanged);
  }

  final RentalRepository _rentalRepository;
  final ToyRepository _toyRepository;
  final TurnoRepository _turnoRepository;

  void _onChanged() => emit(_compute(_rentalRepository.rentals, _toyRepository.toys, _turnoRepository.turnos));

  static DateTime get _startOfDay {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static Toy _toyById(List<Toy> toys, String id) => toys.firstWhere((t) => t.id == id, orElse: () => toys.first);

  static AdminPanelState _compute(List<Rental> rentals, List<Toy> toys, List<Turno> turnos) {
    final startOfDay = _startOfDay;
    final doneToday = rentals.where((r) => r.status == RentalStatus.done && r.endedAt != null && !r.endedAt!.isBefore(startOfDay)).toList();

    final totalGrossToday = doneToday.fold(0.0, (a, r) => a + r.price);

    final trail = <TrailEntry>[
      for (final r in rentals)
        if (!r.startedAt.isBefore(startOfDay))
          (toy: _toyById(toys, r.toyId), rental: r, action: TrailAction.created, at: r.startedAt, actor: r.createdByMonitorName),
      for (final r in doneToday)
        (toy: _toyById(toys, r.toyId), rental: r, action: TrailAction.finished, at: r.endedAt!, actor: r.finishedByMonitorName),
    ]..sort((a, b) => b.at.compareTo(a.at));

    final turnosToday = turnos.where((t) => !t.openedAt.isBefore(startOfDay)).toList()..sort((a, b) => b.openedAt.compareTo(a.openedAt));

    final turnRows = turnosToday.map((turno) {
      final windowEnd = turno.closedAt ?? DateTime.now();
      final inTurno = rentals.where(
        (r) =>
            r.toyId == turno.toyId &&
            r.status == RentalStatus.done &&
            r.endedAt != null &&
            !r.endedAt!.isBefore(turno.openedAt) &&
            !r.endedAt!.isAfter(windowEnd) &&
            r.finishedByMonitorName == turno.monitorName,
      );
      final gross = inTurno.fold(0.0, (a, r) => a + r.price);
      double? diff;
      if (turno.closedAt != null && turno.countedCash != null) {
        final cashExpected = inTurno.where((r) => r.paymentMethod == PaymentMethod.dinheiro).fold(0.0, (a, r) => a + r.price);
        diff = turno.countedCash! - cashExpected;
      }
      return (
        toy: _toyById(toys, turno.toyId),
        monitorName: turno.monitorName,
        locCount: inTurno.length,
        gross: gross,
        isOpen: turno.isOpen,
        diff: diff,
      );
    }).toList();

    return AdminPanelState(
      totalGrossToday: totalGrossToday,
      totalLocToday: doneToday.length,
      turnRows: turnRows,
      trail: trail,
    );
  }

  @override
  Future<void> close() {
    _rentalRepository.removeListener(_onChanged);
    _toyRepository.removeListener(_onChanged);
    _turnoRepository.removeListener(_onChanged);
    return super.close();
  }
}
