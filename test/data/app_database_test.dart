// Tests for spec 020 (persistência local): AppDatabase abre o schema
// corretamente e reusa a mesma instância entre chamadas.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sonho_de_crianca/data/services/app_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('creates the toys and rentals tables', () async {
    final appDatabase = AppDatabase(path: inMemoryDatabasePath);
    final db = await appDatabase.database;

    final tables = await db.query('sqlite_master', where: "type = 'table'", columns: ['name']);
    final names = tables.map((t) => t['name']).toSet();

    expect(names, containsAll(['toys', 'rentals']));

    await appDatabase.close();
  });

  test('database getter caches the same instance across calls', () async {
    final appDatabase = AppDatabase(path: inMemoryDatabasePath);

    final first = await appDatabase.database;
    final second = await appDatabase.database;

    expect(identical(first, second), isTrue);

    await appDatabase.close();
  });
}
