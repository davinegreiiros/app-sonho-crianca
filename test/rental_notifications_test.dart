// Tests for spec 005 (notificações locais de fim de locação): creating a
// fixed-duration rental schedules exactly one notification; cancelling or
// finishing it removes that schedule; tempo corrido (spec 006) never
// schedules one, since it has no target end time.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/models/rental.dart';
import 'package:sonho_de_crianca/state/app_state.dart';

import 'fakes/fake_rental_notifier.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  test('creating a rental schedules one notification for startedAt + durationMin', () {
    final notifier = FakeRentalNotifier();
    final state = AppState(notifications: notifier);
    state.openNew();
    state.setDraftToy('cama'); // blockMin 30
    state.setDraftChild('Sofia Teste Notif');
    state.applyDuration(15);
    state.submitNew();

    final rental = state.rentals.firstWhere((r) => r.childName == 'Sofia Teste Notif');
    expect(notifier.scheduled, contains(rental.id));
    expect(notifier.scheduled[rental.id], rental.startedAt.add(const Duration(minutes: 15)));
    state.dispose();
  });

  test('cancelling an active rental removes its scheduled notification', () {
    final notifier = FakeRentalNotifier();
    final state = AppState(notifications: notifier);
    state.openNew();
    state.setDraftToy('cama');
    state.setDraftChild('Sofia Teste Notif');
    state.submitNew();
    final rental = state.rentals.firstWhere((r) => r.childName == 'Sofia Teste Notif');
    expect(notifier.scheduled, contains(rental.id));

    state.cancelActive(rental.id);
    expect(notifier.scheduled, isNot(contains(rental.id)));
    state.dispose();
  });

  test('finishing a rental early removes its scheduled notification', () {
    final notifier = FakeRentalNotifier();
    final state = AppState(notifications: notifier);
    state.openNew();
    state.setDraftToy('cama');
    state.setDraftChild('Sofia Teste Notif');
    state.submitNew();
    final rental = state.rentals.firstWhere((r) => r.childName == 'Sofia Teste Notif');
    expect(notifier.scheduled, contains(rental.id));

    state.openEnd(rental.id);
    state.selectPayment(PaymentMethod.dinheiro);
    state.confirmEnd();
    expect(notifier.scheduled, isNot(contains(rental.id)));
    state.dispose();
  });

  test('a tempo corrido rental (spec 006) never schedules a notification', () {
    final notifier = FakeRentalNotifier();
    final state = AppState(notifications: notifier);
    state.openNew();
    state.setDraftToy('cama');
    state.setDraftChild('Sofia Teste Notif');
    state.setDraftOpenEnded(true);
    state.submitNew();

    final rental = state.rentals.firstWhere((r) => r.childName == 'Sofia Teste Notif');
    expect(rental.isOpenEnded, isTrue);
    expect(notifier.scheduled, isEmpty);
    state.dispose();
  });
}
