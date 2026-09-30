// Tests for spec 020 (persistência local): ToyLocalService persiste e
// recarrega Toy corretamente, incluindo update via upsert.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sonho_de_crianca/data/services/app_database.dart';
import 'package:sonho_de_crianca/data/services/toy_local_service.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/theme/app_colors.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ToyLocalService service;
  late AppDatabase appDatabase;

  setUp(() {
    appDatabase = AppDatabase(path: inMemoryDatabasePath);
    service = ToyLocalService(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('loadAll on an empty database returns an empty list', () async {
    expect(await service.loadAll(), isEmpty);
  });

  test('upsert then loadAll round-trips every field', () async {
    final toy = Toy(
      id: 'carrinho',
      name: 'Carrinho Elétrico c/ Controle',
      qty: 2,
      blockMin: 15,
      price: 10,
      ink: ToyInk.cyan,
      imageKey: 'carrinho',
      category: ToyCategory.eletrico,
    );

    await service.upsert(toy);
    final loaded = await service.loadAll();

    expect(loaded, hasLength(1));
    final result = loaded.single;
    expect(result.id, toy.id);
    expect(result.name, toy.name);
    expect(result.qty, toy.qty);
    expect(result.blockMin, toy.blockMin);
    expect(result.price, toy.price);
    expect(result.ink, toy.ink);
    expect(result.imageKey, toy.imageKey);
    expect(result.category, toy.category);
  });

  test('upsert with an existing id replaces the row, not duplicates it', () async {
    final toy = Toy(id: 'x', name: 'A', qty: 1, blockMin: 10, price: 5, ink: ToyInk.cyan, imageKey: 'a', category: ToyCategory.outro);
    await service.upsert(toy);

    final updated = toy.copyWith(price: 20);
    await service.upsert(updated);

    final loaded = await service.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.single.price, 20);
  });

  test('delete removes the row', () async {
    final toy = Toy(id: 'x', name: 'A', qty: 1, blockMin: 10, price: 5, ink: ToyInk.cyan, imageKey: 'a', category: ToyCategory.outro);
    await service.upsert(toy);

    await service.delete('x');

    expect(await service.loadAll(), isEmpty);
  });
}
