// Tests for spec 020 (persistência local) — cenário 2 do spec.md: uma
// locação sobrevive a fechar e reabrir o app. Simula isso literalmente:
// constrói Repository/Service contra o MESMO arquivo SQLite (não
// `inMemoryDatabasePath` — esse morre com a conexão, o que mascararia
// justamente o bug que esta spec corrige), num "boot 1" que persiste dado
// e fecha o banco, depois num "boot 2" totalmente novo (Repository/
// Service/AppDatabase recriados do zero, como `main.dart` faz a cada
// abertura real) que só hidrata via `load()`.
//
// Os dois testes de `Toy` que existiam aqui (brinquedo sobrevive reabrir +
// "boot 2 não re-semeia") foram removidos na spec 025-catalogo-sessao-
// dispositivo: `ToyRepository` não persiste mais em SQLite nenhum — o
// catálogo agora vem do backend, não tem "fechar e reabrir o app" local
// pra testar.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/services/app_database.dart';
import 'package:sonho_de_crianca/data/services/rental_local_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late String dbPath;

  setUp(() {
    dbPath = '${Directory.systemTemp.path}/sonho_de_crianca_test_${DateTime.now().microsecondsSinceEpoch}.db';
  });

  tearDown(() async {
    final file = File(dbPath);
    if (file.existsSync()) await file.delete();
  });

  test('a rental survives closing and reopening the app', () async {
    final db1 = AppDatabase(path: dbPath);
    final rentalRepo1 = RentalRepository(localService: RentalLocalService(db1));
    await rentalRepo1.load(); // primeira execução: fica vazia mesmo (sem seed).
    final rental = rentalRepo1.addNew(
      toyId: 'carrinho',
      childName: 'Persistência Teste',
      guardianName: 'Responsável Teste',
      guardianPhone: '',
      durationMin: 15,
      price: 10,
      ratePerMinute: null,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await db1.close();

    final db2 = AppDatabase(path: dbPath);
    final rentalRepo2 = RentalRepository(localService: RentalLocalService(db2));
    await rentalRepo2.load();

    expect(rentalRepo2.rentals.any((r) => r.id == rental.id && r.childName == 'Persistência Teste'), isTrue);

    await db2.close();
  });
}
