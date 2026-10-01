// Tests for spec 018 (migração — locação ativa, estender, cancelar,
// encerrar + Pix): RentalRepository.extend/finish notify (the gap
// AppState's in-place mutation used to leave open), and ActiveRentalsCubit
// is testable without a WidgetTester, staying in sync with AppState when
// Repositories are shared. Sincronizado com o backend desde a spec
// 026-rental-via-backend — mutações agora são `Future` e passam por
// `ApiClient` (contra `MockClient`, nunca o backend real).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/ui/features/rental/view_models/active_rentals_cubit.dart';

import 'fakes/fake_rental_backend.dart';
import 'fakes/fake_rental_notifier.dart';
import 'fakes/fake_toy_backend.dart';

void main() {
  // AppState() loads business Pix settings via SharedPreferences (spec
  // 004) — mock it so that hits the in-memory fake instead of a real
  // platform channel with nothing listening on the other end.
  SharedPreferences.setMockInitialValues({});

  group('RentalRepository.extend/finish', () {
    test('extend() mutates duration/price and notifies', () async {
      final repository = _seededRepository();
      final target = repository.rentals.firstWhere((r) => r.status == RentalStatus.active);
      var notified = false;
      repository.addListener(() => notified = true);

      await repository.extend(target.id, durationMin: 999, price: 123.45);

      final updated = repository.rentals.firstWhere((r) => r.id == target.id);
      expect(updated.durationMin, 999);
      expect(updated.price, 123.45);
      expect(notified, isTrue);
    });

    test('finish() sets status/paymentMethod, optionally overrides price, and notifies', () async {
      final repository = _seededRepository();
      final target = repository.rentals.firstWhere((r) => r.status == RentalStatus.active);
      var notified = false;
      repository.addListener(() => notified = true);

      await repository.finish(target.id, PaymentMethod.pix, finalPrice: 42.0);

      final updated = repository.rentals.firstWhere((r) => r.id == target.id);
      expect(updated.status, RentalStatus.done);
      expect(updated.paymentMethod, PaymentMethod.pix);
      expect(updated.price, 42.0);
      expect(notified, isTrue);
    });

    test('finish() without finalPrice leaves price untouched (fixed-duration rental)', () async {
      final repository = _seededRepository();
      final target = repository.rentals.firstWhere((r) => r.status == RentalStatus.active);
      final originalPrice = target.price;

      await repository.finish(target.id, PaymentMethod.cartao);

      expect(repository.rentals.firstWhere((r) => r.id == target.id).price, originalPrice);
    });
  });

  group('ActiveRentalsCubit', () {
    test('starts with only the seed\'s active rentals (a1-a3)', () {
      final cubit = ActiveRentalsCubit(fakeToyRepository(), _seededRepository(), notifications: FakeRentalNotifier());

      expect(cubit.state.activeRentals, hasLength(3));
      expect(cubit.state.activeRentals.every((r) => r.status == RentalStatus.active), isTrue);

      cubit.close();
    });

    test('1s ticker emits a new state even when the rental list is unchanged', () async {
      final cubit = ActiveRentalsCubit(fakeToyRepository(), _seededRepository(), notifications: FakeRentalNotifier());
      final emitted = <Object>[];
      final sub = cubit.stream.listen(emitted.add);

      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(emitted, isNotEmpty);
      await sub.cancel();
      await cubit.close();
    });

    test('extendActive() grows duration/price and reschedules notifications', () async {
      final rentalRepository = _seededRepository();
      final notifier = FakeRentalNotifier();
      final cubit = ActiveRentalsCubit(fakeToyRepository(), rentalRepository, notifications: notifier);
      final target = rentalRepository.rentals.firstWhere((r) => r.id == 'a1'); // carrinho, 15min, R$10
      final originalDuration = target.durationMin!; // capture before mutating — `target` is the same shared object

      await cubit.extendActive('a1', 10);

      final updated = rentalRepository.rentals.firstWhere((r) => r.id == 'a1');
      expect(updated.durationMin, originalDuration + 10);
      expect(notifier.scheduled.containsKey('a1'), isTrue);

      cubit.close();
    });

    test('cancelActive() marca a locação done (sem pagamento) e cancela notificações', () async {
      final rentalRepository = _seededRepository();
      final notifier = FakeRentalNotifier();
      final cubit = ActiveRentalsCubit(fakeToyRepository(), rentalRepository, notifications: notifier);

      await cubit.cancelActive('a1');

      // spec 026: cancelar não remove — o backend marca `done` sem
      // pagamento (ver `Rental.isCompleted`). Continua na lista, só não
      // conta mais como ativa.
      final canceled = rentalRepository.rentals.firstWhere((r) => r.id == 'a1');
      expect(canceled.status, RentalStatus.done);
      expect(canceled.isCompleted, isFalse);
      expect(cubit.state.activeRentals.any((r) => r.id == 'a1'), isFalse);

      cubit.close();
    });

    test('full end flow: openEnd -> selectPayment -> confirmEnd finishes the rental', () async {
      final rentalRepository = _seededRepository();
      final cubit = ActiveRentalsCubit(fakeToyRepository(), rentalRepository, notifications: FakeRentalNotifier());

      cubit.openEnd('a1');
      expect(cubit.state.endingRental?.id, 'a1');
      cubit.selectPayment(PaymentMethod.dinheiro);
      await cubit.confirmEnd();

      final finished = rentalRepository.rentals.firstWhere((r) => r.id == 'a1');
      expect(finished.status, RentalStatus.done);
      expect(finished.paymentMethod, PaymentMethod.dinheiro);
      expect(cubit.state.endingId, isNull);
      expect(cubit.state.activeRentals.any((r) => r.id == 'a1'), isFalse);

      cubit.close();
    });

    test('showPixQrStep() freezes the price, confirmEnd() reuses the frozen value', () async {
      final toyRepository = fakeToyRepository();
      final rentalRepository = _seededRepository();
      final cubit = ActiveRentalsCubit(toyRepository, rentalRepository, notifications: FakeRentalNotifier());
      // Open-ended rental so computeFinalPrice actually varies with time.
      final openEnded = await rentalRepository.addNew(
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

      await cubit.confirmEnd();

      final finished = rentalRepository.rentals.firstWhere((r) => r.id == openEnded.id);
      expect(finished.price, frozen);
      expect(finished.paymentMethod, PaymentMethod.pix);

      cubit.close();
    });

    test('AppState sees the same rentals after extend/cancel/finish through the shared Repository', () async {
      final toyRepository = fakeToyRepository();
      final rentalRepository = _seededRepository();
      final cubit = ActiveRentalsCubit(toyRepository, rentalRepository, notifications: FakeRentalNotifier());
      final state = AppState(
        notifications: FakeRentalNotifier(),
        toyRepository: toyRepository,
        rentalRepository: rentalRepository,
      );

      await cubit.extendActive('a2', 5);
      expect(state.rentals.firstWhere((r) => r.id == 'a2').durationMin, greaterThan(30));

      await cubit.cancelActive('a3');
      expect(state.rentals.firstWhere((r) => r.id == 'a3').status, RentalStatus.done);

      cubit.openEnd('a1');
      cubit.selectPayment(PaymentMethod.cartao);
      await cubit.confirmEnd();
      expect(state.rentals.firstWhere((r) => r.id == 'a1').status, RentalStatus.done);

      cubit.close();
      state.dispose();
    });
  });
}

/// `fakeSeededRentalRepository` com o backend fake também semeado com os
/// mesmos ids (`a1`-`a3`/`h1`-`h8`) — sem isso, `extend`/`cancel`/`finish`
/// numa locação seedada bateria 404 contra um "servidor" vazio.
RentalRepository _seededRepository() => fakeSeededRentalRepository();
