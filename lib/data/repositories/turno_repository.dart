import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';

import '../../domain/models/turno.dart';
import '../services/turno_local_service.dart';

/// Single source of truth for `Turno`s (spec 023-posto-monitor-painel) —
/// same shape as `RentalRepository`. At most one open `Turno`
/// (`closedAt == null`) per `toyId` at a time: [open] is a no-op (returns
/// the existing one instead) if the posto is already occupied — that's
/// the "retomar" behavior `OpenPostoView` (3a) relies on, not an error
/// path.
class TurnoRepository extends ChangeNotifier {
  TurnoRepository({TurnoLocalService? localService})
      : turnos = [],
        _localService = localService;

  final List<Turno> turnos;
  final TurnoLocalService? _localService;

  bool _disposed = false;

  Future<void> load() async {
    final service = _localService;
    if (service == null) return;
    final loaded = await service.loadAll();
    if (_disposed) return;
    turnos
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  Turno? openTurnoFor(String toyId) {
    for (final t in turnos) {
      if (t.toyId == toyId && t.isOpen) return t;
    }
    return null;
  }

  /// Opens a new `Turno` for [toyId]/[monitorName] — or, if one is
  /// already open for that `toyId`, returns it unchanged (never two
  /// concurrent open turnos for the same posto).
  Turno open(String toyId, String monitorName) {
    final existing = openTurnoFor(toyId);
    if (existing != null) return existing;
    final turno = Turno(
      id: 't${DateTime.now().microsecondsSinceEpoch}',
      toyId: toyId,
      monitorName: monitorName,
      openedAt: DateTime.now(),
    );
    turnos.add(turno);
    notifyListeners();
    unawaited(_persist(turno));
    return turno;
  }

  void close(String turnoId, {required double countedCash}) {
    final t = turnos.firstWhere((t) => t.id == turnoId, orElse: () => turnos.first);
    t.close(countedCash: countedCash);
    notifyListeners();
    unawaited(_persist(t));
  }

  Future<void> _persist(Turno turno) async {
    final service = _localService;
    if (service == null) return;
    try {
      await service.upsert(turno);
    } catch (e) {
      debugPrint('TurnoRepository: falha ao persistir turno ${turno.id}: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
