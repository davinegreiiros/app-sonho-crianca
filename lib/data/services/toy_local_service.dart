import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../domain/models/toy.dart';
import '../../theme/app_colors.dart' show ToyInk;
import 'app_database.dart';

/// Wrapper stateless sobre a tabela `toys` do SQLite (spec
/// 020-persistencia-local) — CRUD puro, sem lógica de negócio. Só
/// `ToyRepository` chama isto.
class ToyLocalService {
  const ToyLocalService(this._db);

  final AppDatabase _db;

  Future<List<Toy>> loadAll() async {
    final db = await _db.database;
    final rows = await db.query('toys');
    return rows.map(_fromRow).toList();
  }

  Future<void> upsert(Toy toy) async {
    final db = await _db.database;
    await db.insert('toys', _toRow(toy), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('toys', where: 'id = ?', whereArgs: [id]);
  }

  Map<String, Object?> _toRow(Toy toy) => {
        'id': toy.id,
        'name': toy.name,
        'qty': toy.qty,
        'block_min': toy.blockMin,
        'price': toy.price,
        'ink': toy.ink.name,
        'image_key': toy.imageKey,
        'category': toy.category.name,
      };

  Toy _fromRow(Map<String, Object?> row) => Toy(
        id: row['id'] as String,
        name: row['name'] as String,
        qty: row['qty'] as int,
        blockMin: row['block_min'] as int,
        price: row['price'] as double,
        ink: ToyInk.values.byName(row['ink'] as String),
        imageKey: row['image_key'] as String,
        category: ToyCategory.values.byName(row['category'] as String),
      );
}
