// Tests for spec 012 (migração — catálogo, criação de brinquedo), spec
// 015 (migração — catálogo, grade e disponibilidade) e spec 025 (catálogo
// via backend + sessão de dispositivo): o Repository agora fala HTTP (via
// `MockClient`, nenhum teste bate no backend real), mas a interface
// pública de leitura/Cubit continua a mesma — e os dois seguem em
// sincronia quando as instâncias são compartilhadas, mesma ponte que
// AppState usa.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/domain/use_cases/compute_toy_availability.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/theme/app_colors.dart';
import 'package:sonho_de_crianca/ui/features/catalog/view_models/toy_catalog_cubit.dart';
import 'package:sonho_de_crianca/ui/features/catalog/view_models/toy_catalog_state.dart';

import 'fakes/fake_rental_backend.dart';
import 'fakes/fake_rental_notifier.dart';
import 'fakes/fake_toy_backend.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  group('ToyRepository', () {
    test('starts seeded from kInitialToys', () {
      final repository = fakeToyRepository();
      expect(repository.toys, kInitialToys);
    });

    test('addNew() appends a toy com o id que o backend devolveu', () async {
      final repository = fakeToyRepository();
      final before = repository.toys.length;

      final toy = await repository.addNew(
        name: 'Brinquedo Teste',
        price: 10,
        blockMin: 15,
        ink: ToyInk.cyan,
        imageKey: 'outro',
        category: ToyCategory.outro,
      );

      expect(repository.toys, hasLength(before + 1));
      expect(kInitialToys.any((t) => t.id == toy.id), isFalse);
    });

    test('updatePrice()/updateBlockMinutes() change only the matching toy', () async {
      final repository = fakeToyRepository(initial: kInitialToys);
      await repository.load();
      final target = repository.toys.first;

      await repository.updatePrice(target.id, 99);
      await repository.updateBlockMinutes(target.id, 42);

      final updated = repository.toys.firstWhere((t) => t.id == target.id);
      expect(updated.price, 99);
      expect(updated.blockMin, 42);
      expect(repository.toys, hasLength(kInitialToys.length));
    });

    test('remove() drops the toy (o Cubit cuida da guarda de locação vinculada)', () async {
      final repository = fakeToyRepository(initial: kInitialToys);
      await repository.load();
      final target = repository.toys.first;

      await repository.remove(target.id);

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
      build: () => ToyCatalogCubit(fakeToyRepository(), fakeRentalRepository()),
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
      final cubit = ToyCatalogCubit(fakeToyRepository(), fakeSeededRentalRepository());

      final carrinho = cubit.state.toys.firstWhere((t) => t.id == 'carrinho'); // qty 2, 1 active (a1)
      final cama = cubit.state.toys.firstWhere((t) => t.id == 'cama'); // qty 1, 0 active

      expect(cubit.state.availabilityOf(carrinho), 1);
      expect(cubit.state.availabilityOf(cama), 1);

      cubit.close();
    });

    test('reacts to a new rental in a shared RentalRepository (availability drops)', () {
      final toyRepository = fakeToyRepository();
      final rentalRepository = fakeRentalRepository();
      final cubit = ToyCatalogCubit(toyRepository, rentalRepository);
      final cama = cubit.state.toys.firstWhere((t) => t.id == 'cama');
      expect(cubit.state.availabilityOf(cama), 1);

      // `RentalRepository.add` foi removido na spec 026 — `rentals` segue
      // mutável, só precisa notificar manualmente.
      rentalRepository.rentals.add(Rental(
        id: 'x-avail-test',
        toyId: 'cama',
        childName: 'Teste',
        guardianName: 'Responsável',
        startedAt: DateTime.now(),
        durationMin: 30,
        price: 15,
        status: RentalStatus.active,
      ));
      rentalRepository.notifyListeners();

      expect(cubit.state.availabilityOf(cama), 0);

      cubit.close();
    });

    test('removeToy() refuses a toy with any rental (active or done), succeeds otherwise', () async {
      final toyRepository = fakeToyRepository();
      final rentalRepository = fakeSeededRentalRepository();
      final cubit = ToyCatalogCubit(toyRepository, rentalRepository);

      // 'carrinho' has rentals in the seed (a1 active, h1/h6 done).
      expect(await cubit.removeToy('carrinho'), isFalse);
      expect(cubit.state.toys.any((t) => t.id == 'carrinho'), isTrue);

      final toy = await cubit.addToy(
        name: 'Sem Locação',
        price: 10,
        blockMin: 15,
        ink: ToyInk.cyan,
        imageKey: 'outro',
        category: ToyCategory.outro,
      );
      expect(await cubit.removeToy(toy.id), isTrue);
      expect(cubit.state.toys.any((t) => t.id == toy.id), isFalse);

      cubit.close();
    });

    test('shares state with AppState.toys when the same Repositories are injected', () async {
      final toyRepository = fakeToyRepository();
      final rentalRepository = fakeRentalRepository();
      final cubit = ToyCatalogCubit(toyRepository, rentalRepository);
      final state = AppState(
        notifications: FakeRentalNotifier(),
        toyRepository: toyRepository,
        rentalRepository: rentalRepository,
      );

      final toy = await cubit.addToy(
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
