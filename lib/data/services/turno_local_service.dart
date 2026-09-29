import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../domain/models/turno.dart';
import 'app_database.dart';

/// Wrapper stateless sobre a tabela `turnos` do SQLite (spec
/// 023-posto-monitor-painel) — CRUD puro, sem lógica de negócio. Só
/// `TurnoRepository` chama isto.
class TurnoLocalService {
  const TurnoLocalService(this._db);

  final AppDatabase _db;

  Future<List<Turno>> loadAll() async {
    final db = await _db.database;
    final rows = await db.query('turnos');
    return rows.map(_fromRow).toList();
  }

  Future<void> upsert(Turno turno) async {
    final db = await _db.database;
    await db.insert('turnos', _toRow(turno), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Map<String, Object?> _toRow(Turno turno) => {
        'id': turno.id,
        'toy_id': turno.toyId,
        'monitor_name': turno.monitorName,
        'opened_at': turno.openedAt.millisecondsSinceEpoch,
        'closed_at': turno.closedAt?.millisecondsSinceEpoch,
        'counted_cash': turno.countedCash,
      };

  Turno _fromRow(Map<String, Object?> row) => Turno(
        id: row['id'] as String,
        toyId: row['toy_id'] as String,
        monitorName: row['monitor_name'] as String,
        openedAt: DateTime.fromMillisecondsSinceEpoch(row['opened_at'] as int),
        closedAt: row['closed_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(row['closed_at'] as int),
        countedCash: row['counted_cash'] as double?,
      );
}
