// Tests for spec 017 (migração — nova locação): RentalRepository.addNew,
// ScheduleRentalEndNotifications and NewRentalCubit are testable without
// a WidgetTester, and the Cubit's submit() lands in the same
// RentalRepository AppState reads from when the instance is shared.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/repositories/toy_repository.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/domain/use_cases/schedule_rental_end_notifications.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/ui/features/rental/view_models/new_rental_cubit.dart';

import 'fakes/fake_rental_notifier.dart';

void main() {
  // AppState() loads business Pix settings via SharedPreferences (spec
  // 004) — mock it so that hits the in-memory fake instead of a real
  // platform channel with nothing listening on the other end.
  SharedPreferences.setMockInitialValues({});

  group('RentalRepository.addNew', () {
    test('builds an active Rental with a unique, non-colliding id and adds it', () {
      final repository = RentalRepository();
      final before = repository.rentals.length;

      final rental = repository.addNew(
        toyId: 'carrinho',
        childName: 'Teste',
        guardianName: 'Responsável',
        guardianPhone: '',
        durationMin: 15,
        price: 10,
        ratePerMinute: null,
      );

      expect(repository.rentals, hasLength(before + 1));
      expect(rental.id, startsWith('r'));
      expect(repository.rentals.any((r) => r.id == rental.id), isTrue);
      expect(rental.status, RentalStatus.active);
      expect(rental.toyId, 'carrinho');
    });
  });

  group('ScheduleRentalEndNotifications', () {
    test('schedules both notifications for a fixed-duration rental', () {
      const scheduleNotifications = ScheduleRentalEndNotifications();
      final notifier = FakeRentalNotifier();
      final toy = ToyRepository().toys.firstWhere((t) => t.id == 'carrinho');
      final rental = Rental(
        id: 'r-notif-test',
        toyId: toy.id,
        childName: 'Teste',
        guardianName: 'Responsável',
        startedAt: DateTime.now(),
        durationMin: 15,
        price: 10,
        status: RentalStatus.active,
      );

      scheduleNotifications(rental, toy, notifier);

      expect(notifier.scheduled.containsKey(rental.id), isTrue);
      expect(notifier.scheduledEndingSoon.containsKey(rental.id), isTrue);
    });

    test('is a no-op for an open-ended rental', () {
      const scheduleNotifications = ScheduleRentalEndNotifications();
      final notifier = FakeRentalNotifier();
      final toy = ToyRepository().toys.firstWhere((t) => t.id == 'carrinho');
      final rental = Rental(
        id: 'r-open-ended-test',
        toyId: toy.id,
        childName: 'Teste',
        guardianName: 'Responsável',
        startedAt: DateTime.now(),
        durationMin: null,
        price: 0,
        status: RentalStatus.active,
        ratePerMinute: 1,
      );

      scheduleNotifications(rental, toy, notifier);

      expect(notifier.scheduled.containsKey(rental.id), isFalse);
      expect(notifier.scheduledEndingSoon.containsKey(rental.id), isFalse);
    });
  });

  group('NewRentalCubit', () {
    test('opens with the first available toy and its default duration/price', () {
      final cubit = NewRentalCubit(ToyRepository(), RentalRepository(), notifications: FakeRentalNotifier());

      // Seed: 'carrinho' (qty 2, 1 active) is first in kInitialToys and
      // still has 1 free unit, so it's the default pick.
      expect(cubit.state.toyId, 'carrinho');
      expect(cubit.state.durationMin, 15);
      expect(cubit.state.price, 10);
      expect(cubit.state.canSubmit, isFalse); // no child name yet

      cubit.close();
    });

    test('setToy() resets duration/price to the new toy and clears the custom rate', () {
      final cubit = NewRentalCubit(ToyRepository(), RentalRepository(), notifications: FakeRentalNotifier());
      cubit.setCustomRate(2.5);

      cubit.setToy('cama'); // qty 1, blockMin 30, price 15

      expect(cubit.state.toyId, 'cama');
      expect(cubit.state.durationMin, 30);
      expect(cubit.state.price, 15);
      expect(cubit.state.customRatePerMinute, isNull);

      cubit.close();
    });

    test('applyDuration() scales price proportionally, same formula as before', () {
      final cubit = NewRentalCubit(ToyRepository(), RentalRepository(), notifications: FakeRentalNotifier());
      cubit.setToy('cama'); // blockMin 30, price 15 -> R$0,50/min

      cubit.applyDuration(10);

      expect(cubit.state.durationMin, 10);
      expect(cubit.state.price, 5); // round(15 * 10/30) = 5

      cubit.close();
    });

    test('submit() writes through RentalRepository and schedules its notifications', () {
      final rentalRepository = RentalRepository();
      final notifier = FakeRentalNotifier();
      final cubit = NewRentalCubit(ToyRepository(), rentalRepository, notifications: notifier);
      cubit.setChildName('Teste Nova Locação');

      final rental = cubit.submit();

      expect(rentalRepository.rentals.any((r) => r.id == rental.id), isTrue);
      expect(rental.childName, 'Teste Nova Locação');
      expect(notifier.scheduled.containsKey(rental.id), isTrue);

      cubit.close();
    });

    test('shares the created rental with AppState.rentals when Repositories are injected', () {
      final toyRepository = ToyRepository();
      final rentalRepository = RentalRepository();
      final cubit = NewRentalCubit(toyRepository, rentalRepository, notifications: FakeRentalNotifier());
      final state = AppState(
        notifications: FakeRentalNotifier(),
        toyRepository: toyRepository,
        rentalRepository: rentalRepository,
      );
      cubit.setChildName('Teste Compartilhado');

      final rental = cubit.submit();

      expect(state.rentals.any((r) => r.id == rental.id), isTrue);

      cubit.close();
      state.dispose();
    });
  });
}
