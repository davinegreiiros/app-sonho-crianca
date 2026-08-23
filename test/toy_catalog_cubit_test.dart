// Tests for spec 012 (migração — catálogo, criação de brinquedo): the new
// Repository/Cubit are testable without a WidgetTester, and stay in sync
// with AppState when a Repository instance is shared — the same bridge
// AppState relies on until catalog_tab.dart migrates in fatia 014.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/toy_repository.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/theme/app_colors.dart';
import 'package:sonho_de_crianca/ui/features/catalog/view_models/toy_catalog_cubit.dart';
import 'package:sonho_de_crianca/ui/features/catalog/view_models/toy_catalog_state.dart';

import 'fakes/fake_rental_notifier.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  group('ToyRepository', () {
    test('starts seeded from kInitialToys', () {
      final repository = ToyRepository();
      expect(repository.toys, kInitialToys);
    });

    test('addNew() appends a toy with a unique, non-colliding id', () {
      final repository = ToyRepository();
      final before = repository.toys.length;

      final toy = repository.addNew(
        name: 'Brinquedo Teste',
        price: 10,
        blockMin: 15,
        ink: ToyInk.cyan,
        imageKey: 'outro',
        category: ToyCategory.outro,
      );

      expect(repository.toys, hasLength(before + 1));
      expect(toy.id, startsWith('custom_'));
      expect(kInitialToys.any((t) => t.id == toy.id), isFalse);
    });

    test('updatePrice()/updateBlockMinutes() change only the matching toy', () {
      final repository = ToyRepository();
      final target = repository.toys.first;

      repository.updatePrice(target.id, 99);
      repository.updateBlockMinutes(target.id, 42);

      final updated = repository.toys.firstWhere((t) => t.id == target.id);
      expect(updated.price, 99);
      expect(updated.blockMin, 42);
      expect(repository.toys, hasLength(kInitialToys.length));
    });

    test('remove() drops the toy unconditionally (the rentals guard lives in AppState)', () {
      final repository = ToyRepository();
      final target = repository.toys.first;

      repository.remove(target.id);

      expect(repository.toys.any((t) => t.id == target.id), isFalse);
    });
  });

  group('ToyCatalogCubit', () {
    blocTest<ToyCatalogCubit, ToyCatalogState>(
      'addToy() persists through the Repository and emits the new state',
      build: () => ToyCatalogCubit(ToyRepository()),
      act: (cubit) => cubit.addToy(
        name: 'Brinquedo Teste',
        price: 10,
        blockMin: 15,
        ink: ToyInk.cyan,
        imageKey: 'outro',
        category: ToyCategory.outro,
      ),
      verify: (cubit) {
        expect(cubit.state.toys, hasLength(kInitialToys.length + 1));
        expect(cubit.state.toys.last.name, 'Brinquedo Teste');
      },
    );

    test('shares state with AppState.toys when the same Repository instance is injected', () {
      final repository = ToyRepository();
      final cubit = ToyCatalogCubit(repository);
      final state = AppState(notifications: FakeRentalNotifier(), toyRepository: repository);

      final toy = cubit.addToy(
        name: 'Brinquedo Teste',
        price: 10,
        blockMin: 15,
        ink: ToyInk.cyan,
        imageKey: 'outro',
        category: ToyCategory.outro,
      );

      // Same Repository instance -> AppState (old world) sees exactly what
      // the new Cubit just added, with no separate/divergent copy.
      expect(state.toys, cubit.state.toys);
      expect(state.toyById(toy.id).name, 'Brinquedo Teste');

      cubit.close();
      state.dispose();
    });
  });
}
