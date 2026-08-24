// Tests for spec 012 (migração — catálogo, criação de brinquedo) and
// spec 015 (migração — catálogo, grade e disponibilidade): the
// Repository/Cubit/Use Case are testable without a WidgetTester, and
// stay in sync with AppState when Repository instances are shared — the
// same bridge AppState relies on until catalog_view.dart's remaining
// unmigrated neighbors (home_tab.dart, new_rental_sheet.dart) move in
// fatia 016.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/repositories/toy_repository.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/domain/use_cases/compute_toy_availability.dart';
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

    test('remove() drops the toy unconditionally (the rentals guard lives in the Cubit)', () {
      final repository = ToyRepository();
      final target = repository.toys.first;

      repository.remove(target.id);

      expect(repository.toys.any((t) => t.id == target.id), isFalse);
    });
  });

  group('ComputeToyAvailability', () {
    test('subtracts only active rentals against that toy', () {
      const compute = ComputeToyAvailability();
      final toy = kInitialToys.firstWhere((t) => t.id == 'carrinho'); // qty 2
      final rentals = [
        Rental(id: 'x1', toyId: 'carrinho', childName: 'A', guardianName: 'B', startedAt: DateTime.now(), durationMin: 15, price: 10, status: RentalStatus.active),
        Rental(id: 'x2', toyId: 'carrinho', childName: 'C', guardianName: 'D', startedAt: DateTime.now(), durationMin: 15, price: 10, status: RentalStatus.done, endedAt: DateTime.now(), paymentMethod: PaymentMethod.pix),
        Rental(id: 'x3', toyId: 'pula', childName: 'E', guardianName: 'F', startedAt: DateTime.now(), durationMin: 15, price: 10, status: RentalStatus.active),
      ];

      // 1 active against 'carrinho' (x1) counts; x2 (done) and x3 (a
      // different toy) don't.
      expect(compute(toy, rentals), 1);
    });
  });

  group('ToyCatalogCubit', () {
    blocTest<ToyCatalogCubit, ToyCatalogState>(
      'addToy() persists through the Repository and emits the new state',
      build: () => ToyCatalogCubit(ToyRepository(), RentalRepository()),
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

    test('availabilityOf() matches the seed (a1/a2/a3 active against carrinho/pula/patinete)', () {
      final cubit = ToyCatalogCubit(ToyRepository(), RentalRepository.withDemoSeed());

      final carrinho = cubit.state.toys.firstWhere((t) => t.id == 'carrinho'); // qty 2, 1 active (a1)
      final cama = cubit.state.toys.firstWhere((t) => t.id == 'cama'); // qty 1, 0 active

      expect(cubit.state.availabilityOf(carrinho), 1);
      expect(cubit.state.availabilityOf(cama), 1);

      cubit.close();
    });

    test('reacts to a new rental in a shared RentalRepository (availability drops)', () {
      final toyRepository = ToyRepository();
      final rentalRepository = RentalRepository();
      final cubit = ToyCatalogCubit(toyRepository, rentalRepository);
      final cama = cubit.state.toys.firstWhere((t) => t.id == 'cama');
      expect(cubit.state.availabilityOf(cama), 1);

      rentalRepository.add(Rental(
        id: 'x-avail-test',
        toyId: 'cama',
        childName: 'Teste',
        guardianName: 'Responsável',
        startedAt: DateTime.now(),
        durationMin: 30,
        price: 15,
        status: RentalStatus.active,
      ));

      expect(cubit.state.availabilityOf(cama), 0);

      cubit.close();
    });

    test('removeToy() refuses a toy with any rental (active or done), succeeds otherwise', () {
      final toyRepository = ToyRepository();
      final rentalRepository = RentalRepository.withDemoSeed();
      final cubit = ToyCatalogCubit(toyRepository, rentalRepository);

      // 'carrinho' has rentals in the seed (a1 active, h1/h6 done).
      expect(cubit.removeToy('carrinho'), isFalse);
      expect(cubit.state.toys.any((t) => t.id == 'carrinho'), isTrue);

      final toy = cubit.addToy(
        name: 'Sem Locação',
        price: 10,
        blockMin: 15,
        ink: ToyInk.cyan,
        imageKey: 'outro',
        category: ToyCategory.outro,
      );
      expect(cubit.removeToy(toy.id), isTrue);
      expect(cubit.state.toys.any((t) => t.id == toy.id), isFalse);

      cubit.close();
    });

    test('shares state with AppState.toys when the same Repositories are injected', () {
      final toyRepository = ToyRepository();
      final rentalRepository = RentalRepository();
      final cubit = ToyCatalogCubit(toyRepository, rentalRepository);
      final state = AppState(
        notifications: FakeRentalNotifier(),
        toyRepository: toyRepository,
        rentalRepository: rentalRepository,
      );

      final toy = cubit.addToy(
        name: 'Brinquedo Teste',
        price: 10,
        blockMin: 15,
        ink: ToyInk.cyan,
        imageKey: 'outro',
        category: ToyCategory.outro,
      );

      // Same Repository instances -> AppState (old world) sees exactly
      // what the new Cubit just added/computed, with no divergent copy.
      expect(state.toys, cubit.state.toys);
      expect(state.toyById(toy.id).name, 'Brinquedo Teste');
      final carrinho = state.toyById('carrinho');
      expect(state.toyAvailable(carrinho), cubit.state.availabilityOf(carrinho));

      cubit.close();
      state.dispose();
    });
  });
}
