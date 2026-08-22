// Tests for spec 008 (adicionar tempo e alarme visual): extending an
// active fixed-duration rental adds minutes and proportional price, and
// reschedules its end notification; a tempo corrido (spec 006) rental is
// untouched by it, since it has no fixed duration to extend.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/state/app_state.dart';

import 'fakes/fake_rental_notifier.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  test('extendActive adds minutes and proportional price, reschedules notification', () {
    final notifier = FakeRentalNotifier();
    final state = AppState(notifications: notifier);
    state.openNew();
    state.setDraftToy('cama'); // blockMin 30, price 15 -> R$0,50/min
    state.setDraftChild('Sofia Teste Extend');
    state.applyDuration(15); // price = round(15 * 15/30) = 8
    state.submitNew();

    final rental = state.rentals.firstWhere((r) => r.childName == 'Sofia Teste Extend');
    expect(rental.durationMin, 15);
    expect(rental.price, 8);
    final originalSchedule = notifier.scheduled[rental.id];
    expect(originalSchedule, rental.startedAt.add(const Duration(minutes: 15)));

    state.extendActive(rental.id, 10);

    expect(rental.durationMin, 25);
    expect(rental.price, 13); // 8 + 0.5/min * 10min
    expect(notifier.scheduled[rental.id], rental.startedAt.add(const Duration(minutes: 25)));
    expect(notifier.scheduled[rental.id], isNot(originalSchedule));
    state.dispose();
  });

  test('extendActive is a no-op on a tempo corrido (open-ended) rental', () {
    final notifier = FakeRentalNotifier();
    final state = AppState(notifications: notifier);
    state.openNew();
    state.setDraftToy('cama');
    state.setDraftChild('Sofia Teste Extend Aberta');
    state.setDraftOpenEnded(true);
    state.submitNew();

    final rental = state.rentals.firstWhere((r) => r.childName == 'Sofia Teste Extend Aberta');
    expect(rental.isOpenEnded, isTrue);
    final priceBefore = rental.price;

    state.extendActive(rental.id, 10);

    expect(rental.durationMin, isNull);
    expect(rental.price, priceBefore);
    expect(notifier.scheduled, isEmpty);
    state.dispose();
  });
}
