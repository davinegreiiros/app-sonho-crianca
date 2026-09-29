// Tests for spec 005 (notificações locais de fim de locação) + spec 009
// (reformatação + aviso prévio de 5 min): creating a fixed-duration
// rental schedules the "time's up" notification and the separate "5
// minutes left" one; cancelling or finishing it removes both; tempo
// corrido (spec 006) never schedules either, since it has no target end
// time.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/state/app_state.dart';

import 'fakes/fake_rental_notifier.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  test('creating a rental schedules the end notification for startedAt + durationMin', () {
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

  test('creating a rental also schedules the "5 minutes left" heads-up for endsAt - 5min', () {
    final notifier = FakeRentalNotifier();
    final state = AppState(notifications: notifier);
    state.openNew();
    state.setDraftToy('cama');
    state.setDraftChild('Sofia Teste Notif');
    state.applyDuration(15);
    state.submitNew();

    final rental = state.rentals.firstWhere((r) => r.childName == 'Sofia Teste Notif');
    expect(notifier.scheduledEndingSoon, contains(rental.id));
    expect(notifier.scheduledEndingSoon[rental.id], rental.startedAt.add(const Duration(minutes: 10)));
    state.dispose();
  });

  test('a rental of 5 minutes or less never schedules the "5 minutes left" heads-up', () {
    final notifier = FakeRentalNotifier();
    final state = AppState(notifications: notifier);
    state.openNew();
    state.setDraftToy('cama');
    state.setDraftChild('Sofia Teste Notif');
    state.applyDuration(5);
    state.submitNew();

    final rental = state.rentals.firstWhere((r) => r.childName == 'Sofia Teste Notif');
    expect(notifier.scheduled, contains(rental.id)); // end notification still scheduled
    expect(notifier.scheduledEndingSoon, isNot(contains(rental.id)));
    state.dispose();
  });

  test('cancelling an active rental removes both scheduled notifications', () {
    final notifier = FakeRentalNotifier();
    final state = AppState(notifications: notifier);
    state.openNew();
    state.setDraftToy('cama');
    state.setDraftChild('Sofia Teste Notif');
    state.submitNew();
    final rental = state.rentals.firstWhere((r) => r.childName == 'Sofia Teste Notif');
    expect(notifier.scheduled, contains(rental.id));
    expect(notifier.scheduledEndingSoon, contains(rental.id));

    state.cancelActive(rental.id);
    expect(notifier.scheduled, isNot(contains(rental.id)));
    expect(notifier.scheduledEndingSoon, isNot(contains(rental.id)));
    state.dispose();
  });

  test('finishing a rental early removes both scheduled notifications', () {
    final notifier = FakeRentalNotifier();
    final state = AppState(notifications: notifier);
    state.openNew();
    state.setDraftToy('cama');
    state.setDraftChild('Sofia Teste Notif');
    state.submitNew();
    final rental = state.rentals.firstWhere((r) => r.childName == 'Sofia Teste Notif');
    expect(notifier.scheduled, contains(rental.id));
    expect(notifier.scheduledEndingSoon, contains(rental.id));

    state.openEnd(rental.id);
    state.selectPayment(PaymentMethod.dinheiro);
    state.confirmEnd();
    expect(notifier.scheduled, isNot(contains(rental.id)));
    expect(notifier.scheduledEndingSoon, isNot(contains(rental.id)));
    state.dispose();
  });

  test('a tempo corrido rental (spec 006) never schedules either notification', () {
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
    expect(notifier.scheduledEndingSoon, isEmpty);
    state.dispose();
  });
}
