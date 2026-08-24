// Tests for spec 019 (migração — painel do dia): HomeCubit replicates
// AppState's old recentActivity/doneToday/homeTotalToday/availability
// formulas and stays in sync with AppState when Repositories are shared.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/repositories/toy_repository.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/ui/features/home/view_models/home_cubit.dart';

import 'fakes/fake_rental_notifier.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  group('HomeCubit', () {
    test('seed: 3 active, h1-h3 finished today (35 total), h4-h8 finished earlier', () {
      final cubit = HomeCubit(ToyRepository(), RentalRepository.withDemoSeed());

      expect(cubit.state.activeCount, 3);
      expect(cubit.state.doneTodayCount, 3);
      expect(cubit.state.homeTotalToday, 10 + 15 + 10); // h1 + h2 + h3

      cubit.close();
    });

    test('recentActivity mixes active + done-today, most recent first, capped at 4', () {
      final cubit = HomeCubit(ToyRepository(), RentalRepository.withDemoSeed());

      expect(cubit.state.recentActivity, hasLength(4));
      for (var i = 1; i < cubit.state.recentActivity.length; i++) {
        final prev = cubit.state.recentActivity[i - 1];
        final cur = cubit.state.recentActivity[i];
        final prevTs = prev.status == RentalStatus.active ? prev.startedAt : prev.endedAt!;
        final curTs = cur.status == RentalStatus.active ? cur.startedAt : cur.endedAt!;
        expect(prevTs.isAfter(curTs) || prevTs.isAtSameMomentAs(curTs), isTrue);
      }

      cubit.close();
    });

    test('availableCount sums ComputeToyAvailability across the whole catalog', () {
      final cubit = HomeCubit(ToyRepository(), RentalRepository.withDemoSeed());

      // carrinho(2,-1)+cama(1)+pula(2,-1)+piscina(1)+patinete(2,-1) = 1+1+1+1+1 = 5
      expect(cubit.state.availableCount, 5);

      cubit.close();
    });

    test('reacts to a new rental in a shared RentalRepository', () {
      final toyRepository = ToyRepository();
      final rentalRepository = RentalRepository();
      final cubit = HomeCubit(toyRepository, rentalRepository);
      final before = cubit.state.activeCount;

      rentalRepository.add(Rental(
        id: 'r-home-test',
        toyId: 'carrinho',
        childName: 'Teste',
        guardianName: 'Responsável',
        startedAt: DateTime.now(),
        durationMin: 15,
        price: 10,
        status: RentalStatus.active,
      ));

      expect(cubit.state.activeCount, before + 1);

      cubit.close();
    });

    test('shares state with AppState when the same Repositories are injected', () {
      final toyRepository = ToyRepository();
      final rentalRepository = RentalRepository();
      final cubit = HomeCubit(toyRepository, rentalRepository);
      final state = AppState(
        notifications: FakeRentalNotifier(),
        toyRepository: toyRepository,
        rentalRepository: rentalRepository,
      );

      expect(cubit.state.activeCount, state.activeRentals.length);

      cubit.close();
      state.dispose();
    });
  });
}
