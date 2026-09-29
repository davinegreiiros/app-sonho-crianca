// Tests for spec 018 (migração — locação ativa, estender, cancelar,
// encerrar + Pix): RentalRepository.extend/finish notify (the gap
// AppState's in-place mutation used to leave open), and ActiveRentalsCubit
// is testable without a WidgetTester, staying in sync with AppState when
// Repositories are shared.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/repositories/toy_repository.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/ui/features/rental/view_models/active_rentals_cubit.dart';

import 'fakes/fake_rental_notifier.dart';

void main() {
  // AppState() loads business Pix settings via SharedPreferences (spec
  // 004) — mock it so that hits the in-memory fake instead of a real
  // platform channel with nothing listening on the other end.
  SharedPreferences.setMockInitialValues({});

  group('RentalRepository.extend/finish', () {
    test('extend() mutates duration/price and notifies', () {
      final repository = RentalRepository.withDemoSeed();
      final target = repository.rentals.firstWhere((r) => r.status == RentalStatus.active);
      var notified = false;
      repository.addListener(() => notified = true);

      repository.extend(target.id, durationMin: 999, price: 123.45);

      final updated = repository.rentals.firstWhere((r) => r.id == target.id);
      expect(updated.durationMin, 999);
      expect(updated.price, 123.45);
      expect(notified, isTrue);
    });

    test('finish() sets status/paymentMethod, optionally overrides price, and notifies', () {
      final repository = RentalRepository.withDemoSeed();
      final target = repository.rentals.firstWhere((r) => r.status == RentalStatus.active);
      var notified = false;
      repository.addListener(() => notified = true);

      repository.finish(target.id, PaymentMethod.pix, finalPrice: 42.0);

      final updated = repository.rentals.firstWhere((r) => r.id == target.id);
      expect(updated.status, RentalStatus.done);
      expect(updated.paymentMethod, PaymentMethod.pix);
      expect(updated.price, 42.0);
      expect(notified, isTrue);
    });

    test('finish() without finalPrice leaves price untouched (fixed-duration rental)', () {
      final repository = RentalRepository.withDemoSeed();
      final target = repository.rentals.firstWhere((r) => r.status == RentalStatus.active);
      final originalPrice = target.price;

      repository.finish(target.id, PaymentMethod.cartao);

      expect(repository.rentals.firstWhere((r) => r.id == target.id).price, originalPrice);
    });
  });

  group('ActiveRentalsCubit', () {
    test('starts with only the seed\'s active rentals (a1-a3)', () {
      final cubit = ActiveRentalsCubit(ToyRepository(), RentalRepository.withDemoSeed(), notifications: FakeRentalNotifier());

      expect(cubit.state.activeRentals, hasLength(3));
      expect(cubit.state.activeRentals.every((r) => r.status == RentalStatus.active), isTrue);

      cubit.close();
    });

    test('extendActive() grows duration/price and reschedules notifications', () {
      final rentalRepository = RentalRepository.withDemoSeed();
      final notifier = FakeRentalNotifier();
      final cubit = ActiveRentalsCubit(ToyRepository(), rentalRepository, notifications: notifier);
      final target = rentalRepository.rentals.firstWhere((r) => r.id == 'a1'); // carrinho, 15min, R$10
      final originalDuration = target.durationMin!; // capture before mutating — `target` is the same shared object

      cubit.extendActive('a1', 10);

      final updated = rentalRepository.rentals.firstWhere((r) => r.id == 'a1');
      expect(updated.durationMin, originalDuration + 10);
      expect(notifier.scheduled.containsKey('a1'), isTrue);

      cubit.close();
    });

    test('cancelActive() removes the rental and cancels its notifications', () {
      final rentalRepository = RentalRepository.withDemoSeed();
      final notifier = FakeRentalNotifier();
      final cubit = ActiveRentalsCubit(ToyRepository(), rentalRepository, notifications: notifier);

      cubit.cancelActive('a1');

      expect(rentalRepository.rentals.any((r) => r.id == 'a1'), isFalse);
      expect(cubit.state.activeRentals.any((r) => r.id == 'a1'), isFalse);

      cubit.close();
    });

    test('full end flow: openEnd -> selectPayment -> confirmEnd finishes the rental', () {
      final rentalRepository = RentalRepository.withDemoSeed();
      final cubit = ActiveRentalsCubit(ToyRepository(), rentalRepository, notifications: FakeRentalNotifier());

      cubit.openEnd('a1');
      expect(cubit.state.endingRental?.id, 'a1');
      cubit.selectPayment(PaymentMethod.dinheiro);
      cubit.confirmEnd();

      final finished = rentalRepository.rentals.firstWhere((r) => r.id == 'a1');
      expect(finished.status, RentalStatus.done);
      expect(finished.paymentMethod, PaymentMethod.dinheiro);
      expect(cubit.state.endingId, isNull);
      expect(cubit.state.activeRentals.any((r) => r.id == 'a1'), isFalse);

      cubit.close();
    });

    test('showPixQrStep() freezes the price, confirmEnd() reuses the frozen value', () {
      final toyRepository = ToyRepository();
      final rentalRepository = RentalRepository.withDemoSeed();
      final cubit = ActiveRentalsCubit(toyRepository, rentalRepository, notifications: FakeRentalNotifier());
      // Open-ended rental so computeFinalPrice actually varies with time.
      final openEnded = rentalRepository.addNew(
        toyId: 'cama',
        childName: 'Teste Pix',
        guardianName: 'Responsável',
        guardianPhone: '',
        durationMin: null,
        price: 0,
        ratePerMinute: 0.5,
      );

      cubit.openEnd(openEnded.id);
      cubit.selectPayment(PaymentMethod.pix);
      cubit.showPixQrStep();
      final frozen = cubit.state.endFrozenPrice;
      expect(frozen, isNotNull);

      cubit.confirmEnd();

      final finished = rentalRepository.rentals.firstWhere((r) => r.id == openEnded.id);
      expect(finished.price, frozen);
      expect(finished.paymentMethod, PaymentMethod.pix);

      cubit.close();
    });

    test('AppState sees the same rentals after extend/cancel/finish through the shared Repository', () {
      final toyRepository = ToyRepository();
      final rentalRepository = RentalRepository.withDemoSeed();
      final cubit = ActiveRentalsCubit(toyRepository, rentalRepository, notifications: FakeRentalNotifier());
      final state = AppState(
        notifications: FakeRentalNotifier(),
        toyRepository: toyRepository,
        rentalRepository: rentalRepository,
      );

      cubit.extendActive('a2', 5);
      expect(state.rentals.firstWhere((r) => r.id == 'a2').durationMin, greaterThan(30));

      cubit.cancelActive('a3');
      expect(state.rentals.any((r) => r.id == 'a3'), isFalse);

      cubit.openEnd('a1');
      cubit.selectPayment(PaymentMethod.cartao);
      cubit.confirmEnd();
      expect(state.rentals.firstWhere((r) => r.id == 'a1').status, RentalStatus.done);

      cubit.close();
      state.dispose();
    });
  });
}
