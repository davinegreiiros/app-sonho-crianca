// Tests for spec 013 (migração — RentalRepository, fundação): the new
// Repository is testable without a WidgetTester, seeds the exact same
// data AppState._seed() used to, and stays in sync with AppState when a
// Repository instance is shared — same bridge the fatias 014-016 Cubits
// will use once they land.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/state/app_state.dart';

import 'fakes/fake_rental_notifier.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  group('RentalRepository', () {
    test('seeds the same 11 rentals AppState used to (3 active, 8 done)', () {
      final repository = RentalRepository();

      expect(repository.rentals, hasLength(11));
      expect(repository.rentals.map((r) => r.id), containsAll(['a1', 'a2', 'a3', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'h7', 'h8']));
      expect(repository.rentals.where((r) => r.status == RentalStatus.active), hasLength(3));
      expect(repository.rentals.where((r) => r.status == RentalStatus.done), hasLength(8));
    });

    test('add() appends and notifies', () {
      final repository = RentalRepository();
      var notified = false;
      repository.addListener(() => notified = true);

      repository.add(Rental(
        id: 'r1',
        toyId: 'carrinho',
        childName: 'Teste',
        guardianName: 'Responsável Teste',
        startedAt: DateTime.now(),
        durationMin: 15,
        price: 10,
        status: RentalStatus.active,
      ));

      expect(repository.rentals, hasLength(12));
      expect(repository.rentals.any((r) => r.id == 'r1'), isTrue);
      expect(notified, isTrue);
    });

    test('removeById() drops the matching rental and notifies', () {
      final repository = RentalRepository();
      var notified = false;
      repository.addListener(() => notified = true);

      repository.removeById('a1');

      expect(repository.rentals.any((r) => r.id == 'a1'), isFalse);
      expect(repository.rentals, hasLength(10));
      expect(notified, isTrue);
    });
  });

  test('AppState.rentals reflects the same Repository instance when injected', () {
    final repository = RentalRepository();
    final state = AppState(notifications: FakeRentalNotifier(), rentalRepository: repository);

    repository.removeById('a1');

    // Same Repository instance -> AppState sees the change immediately,
    // no separate/divergent copy of the list.
    expect(state.rentals, repository.rentals);
    expect(state.rentals.any((r) => r.id == 'a1'), isFalse);

    state.dispose();
  });
}
