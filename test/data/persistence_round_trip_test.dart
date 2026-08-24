// Tests for spec 020 (persistência local) — cenários 1 e 2 do spec.md:
// um brinquedo customizado e uma locação sobrevivem a fechar e reabrir o
// app. Simula isso literalmente: constrói Repositories/Services contra o
// MESMO arquivo SQLite (não `inMemoryDatabasePath` — esse morre com a
// conexão, o que mascararia justamente o bug que esta spec corrige), num
// "boot 1" que persiste dado e fecha o banco, depois num "boot 2"
// totalmente novo (Repositories/Services/AppDatabase recriados do zero,
// como `main.dart` faz a cada abertura real) que só hidrata via `load()`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/repositories/toy_repository.dart';
import 'package:sonho_de_crianca/data/services/app_database.dart';
import 'package:sonho_de_crianca/data/services/rental_local_service.dart';
import 'package:sonho_de_crianca/data/services/toy_local_service.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/theme/app_colors.dart';

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

  test('a custom toy survives closing and reopening the app', () async {
    // "Boot 1": cria o brinquedo, persiste, fecha o banco (equivalente a
    // fechar o app).
    final db1 = AppDatabase(path: dbPath);
    final toyRepo1 = ToyRepository(localService: ToyLocalService(db1));
    await toyRepo1.load(); // primeira execução: semeia kInitialToys.
    // Dá tempo da escrita da seed (fire-and-forget) terminar antes de
    // seguir — só higiene do teste (evita log de erro por `close()`
    // correndo na frente), não afeta o que está sendo provado.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final custom = toyRepo1.addNew(
      name: 'Brinquedo Persistência Teste',
      price: 20,
      blockMin: 15,
      ink: ToyInk.cyan,
      imageKey: 'outro',
      category: ToyCategory.outro,
    );
    // Dá tempo da escrita otimista (fire-and-forget) terminar antes de
    // "fechar o app" — em produção o app fica aberto bem mais que isso
    // entre a ação e o fechamento real.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await db1.close();

    // "Boot 2": tudo novo — mesmo que `main.dart` recria a cada abertura
    // real — apontando pro mesmo arquivo.
    final db2 = AppDatabase(path: dbPath);
    final toyRepo2 = ToyRepository(localService: ToyLocalService(db2));
    await toyRepo2.load();

    expect(toyRepo2.toys.any((t) => t.id == custom.id && t.name == 'Brinquedo Persistência Teste'), isTrue);

    await db2.close();
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

  test('the second real boot does not reseed kInitialToys on top of persisted data', () async {
    // Regressão específica: se `load()` reseedasse toda vez que a tabela
    // não estivesse "vazia por acaso" checada errado, o catálogo cresceria
    // a cada boot. Prova que o total de brinquedos não muda entre boots.
    final db1 = AppDatabase(path: dbPath);
    final toyRepo1 = ToyRepository(localService: ToyLocalService(db1));
    await toyRepo1.load();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final countAfterFirstBoot = toyRepo1.toys.length;
    await db1.close();

    final db2 = AppDatabase(path: dbPath);
    final toyRepo2 = ToyRepository(localService: ToyLocalService(db2));
    await toyRepo2.load();

    expect(toyRepo2.toys.length, countAfterFirstBoot);

    await db2.close();
  });
}
