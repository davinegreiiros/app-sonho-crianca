// Tests for spec 020 (persistência local): RentalLocalService persiste e
// recarrega Rental corretamente, incluindo campos nulos (locação aberta) e
// upsert de uma locação existente (extend/finish).

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sonho_de_crianca/data/services/app_database.dart';
import 'package:sonho_de_crianca/data/services/rental_local_service.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late RentalLocalService service;
  late AppDatabase appDatabase;

  setUp(() {
    appDatabase = AppDatabase(path: inMemoryDatabasePath);
    service = RentalLocalService(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('loadAll on an empty database returns an empty list', () async {
    expect(await service.loadAll(), isEmpty);
  });

  test('upsert then loadAll round-trips a finished fixed-duration rental', () async {
    final rental = Rental(
      id: 'h1',
      toyId: 'carrinho',
      childName: 'Davi',
      guardianName: 'Renata Alves',
      guardianPhone: '(85) 90000-0000',
      startedAt: DateTime(2026, 8, 24, 9, 0),
      durationMin: 15,
      price: 10,
      status: RentalStatus.done,
      endedAt: DateTime(2026, 8, 24, 9, 15),
      paymentMethod: PaymentMethod.pix,
    );

    await service.upsert(rental);
    final loaded = (await service.loadAll()).single;

    expect(loaded.id, rental.id);
    expect(loaded.toyId, rental.toyId);
    expect(loaded.childName, rental.childName);
    expect(loaded.guardianName, rental.guardianName);
    expect(loaded.guardianPhone, rental.guardianPhone);
    expect(loaded.startedAt, rental.startedAt);
    expect(loaded.durationMin, rental.durationMin);
    expect(loaded.price, rental.price);
    expect(loaded.status, rental.status);
    expect(loaded.endedAt, rental.endedAt);
    expect(loaded.paymentMethod, rental.paymentMethod);
  });

  test('open-ended active rental round-trips null durationMin/endedAt/paymentMethod', () async {
    final rental = Rental(
      id: 'a1',
      toyId: 'carrinho',
      childName: 'Sofia',
      guardianName: 'Camila Ramos',
      startedAt: DateTime(2026, 8, 24, 9, 0),
      durationMin: null,
      ratePerMinute: 0.5,
      price: 0,
      status: RentalStatus.active,
    );

    await service.upsert(rental);
    final loaded = (await service.loadAll()).single;

    expect(loaded.isOpenEnded, isTrue);
    expect(loaded.durationMin, isNull);
    expect(loaded.ratePerMinute, 0.5);
    expect(loaded.endedAt, isNull);
    expect(loaded.paymentMethod, isNull);
  });

  test('upsert with an existing id replaces the row (extend/finish)', () async {
    final rental = Rental(
      id: 'a1',
      toyId: 'carrinho',
      childName: 'Sofia',
      guardianName: 'Camila Ramos',
      startedAt: DateTime(2026, 8, 24, 9, 0),
      durationMin: 15,
      price: 10,
      status: RentalStatus.active,
    );
    await service.upsert(rental);

    rental.finish(PaymentMethod.cartao);
    await service.upsert(rental);

    final loaded = await service.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.single.status, RentalStatus.done);
    expect(loaded.single.paymentMethod, PaymentMethod.cartao);
  });

  test('delete removes the row', () async {
    final rental = Rental(
      id: 'a1',
      toyId: 'carrinho',
      childName: 'Sofia',
      guardianName: 'Camila Ramos',
      startedAt: DateTime.now(),
      durationMin: 15,
      price: 10,
      status: RentalStatus.active,
    );
    await service.upsert(rental);

    await service.delete('a1');

    expect(await service.loadAll(), isEmpty);
  });
}
