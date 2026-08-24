import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../domain/models/rental.dart';
import 'app_database.dart';

/// Wrapper stateless sobre a tabela `rentals` do SQLite (spec
/// 020-persistencia-local) — CRUD puro, sem lógica de negócio. Só
/// `RentalRepository` chama isto.
class RentalLocalService {
  const RentalLocalService(this._db);

  final AppDatabase _db;

  Future<List<Rental>> loadAll() async {
    final db = await _db.database;
    final rows = await db.query('rentals');
    return rows.map(_fromRow).toList();
  }

  Future<void> upsert(Rental rental) async {
    final db = await _db.database;
    await db.insert('rentals', _toRow(rental), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('rentals', where: 'id = ?', whereArgs: [id]);
  }

  Map<String, Object?> _toRow(Rental rental) => {
        'id': rental.id,
        'toy_id': rental.toyId,
        'child_name': rental.childName,
        'guardian_name': rental.guardianName,
        'guardian_phone': rental.guardianPhone,
        'started_at': rental.startedAt.millisecondsSinceEpoch,
        'duration_min': rental.durationMin,
        'rate_per_minute': rental.ratePerMinute,
        'price': rental.price,
        'status': rental.status.name,
        'ended_at': rental.endedAt?.millisecondsSinceEpoch,
        'payment_method': rental.paymentMethod?.name,
      };

  Rental _fromRow(Map<String, Object?> row) => Rental(
        id: row['id'] as String,
        toyId: row['toy_id'] as String,
        childName: row['child_name'] as String,
        guardianName: row['guardian_name'] as String,
        guardianPhone: row['guardian_phone'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
        durationMin: row['duration_min'] as int?,
        ratePerMinute: row['rate_per_minute'] as double?,
        price: row['price'] as double,
        status: RentalStatus.values.byName(row['status'] as String),
        endedAt: row['ended_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(row['ended_at'] as int),
        paymentMethod: row['payment_method'] == null ? null : PaymentMethod.values.byName(row['payment_method'] as String),
      );
}
