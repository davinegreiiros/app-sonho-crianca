// Tests for spec 005 (notificações locais de fim de locação) + spec 009
// (reformatação + aviso prévio de 5 min): creating a fixed-duration
// rental schedules the "time's up" notification and the separate "5
// minutes left" one; cancelling or finishing it removes both; tempo
// corrido (spec 006) never schedules either, since it has no target end
// time.
//
// Migrado na spec 026-rental-via-backend: `AppState.submitNew`/
// `cancelActive`/`confirmEnd` foram removidos (ver `RentalFlowRig`) —
// aciona `NewRentalCubit`/`ActiveRentalsCubit` direto.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/domain/models/rental.dart';

import 'fakes/fake_rental_notifier.dart';
import 'fakes/rental_flow_rig.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  test('creating a rental schedules the end notification for startedAt + durationMin', () async {
    final notifier = FakeRentalNotifier();
    final rig = RentalFlowRig(notifications: notifier);
    rig.newRentalCubit.setToy('cama'); // blockMin 30
    rig.newRentalCubit.setChildName('Sofia Teste Notif');
    rig.newRentalCubit.applyDuration(15);
    final rental = await rig.newRentalCubit.submit();

    expect(notifier.scheduled, contains(rental.id));
    expect(notifier.scheduled[rental.id], rental.startedAt.add(const Duration(minutes: 15)));
    rig.dispose();
  });

  test('creating a rental also schedules the "5 minutes left" heads-up for endsAt - 5min', () async {
    final notifier = FakeRentalNotifier();
    final rig = RentalFlowRig(notifications: notifier);
    rig.newRentalCubit.setToy('cama');
    rig.newRentalCubit.setChildName('Sofia Teste Notif');
    rig.newRentalCubit.applyDuration(15);
    final rental = await rig.newRentalCubit.submit();

    expect(notifier.scheduledEndingSoon, contains(rental.id));
    expect(notifier.scheduledEndingSoon[rental.id], rental.startedAt.add(const Duration(minutes: 10)));
    rig.dispose();
  });

  test('a rental of 5 minutes or less never schedules the "5 minutes left" heads-up', () async {
    final notifier = FakeRentalNotifier();
    final rig = RentalFlowRig(notifications: notifier);
    rig.newRentalCubit.setToy('cama');
    rig.newRentalCubit.setChildName('Sofia Teste Notif');
    rig.newRentalCubit.applyDuration(5);
    final rental = await rig.newRentalCubit.submit();

    expect(notifier.scheduled, contains(rental.id)); // end notification still scheduled
    expect(notifier.scheduledEndingSoon, isNot(contains(rental.id)));
    rig.dispose();
  });

  test('cancelling an active rental removes both scheduled notifications', () async {
    final notifier = FakeRentalNotifier();
    final rig = RentalFlowRig(notifications: notifier);
    rig.newRentalCubit.setToy('cama');
    rig.newRentalCubit.setChildName('Sofia Teste Notif');
    final rental = await rig.newRentalCubit.submit();
    expect(notifier.scheduled, contains(rental.id));
    expect(notifier.scheduledEndingSoon, contains(rental.id));

    await rig.activeRentalsCubit.cancelActive(rental.id);
    expect(notifier.scheduled, isNot(contains(rental.id)));
    expect(notifier.scheduledEndingSoon, isNot(contains(rental.id)));
    rig.dispose();
  });

  test('finishing a rental early removes both scheduled notifications', () async {
    final notifier = FakeRentalNotifier();
    final rig = RentalFlowRig(notifications: notifier);
    rig.newRentalCubit.setToy('cama');
    rig.newRentalCubit.setChildName('Sofia Teste Notif');
    final rental = await rig.newRentalCubit.submit();
    expect(notifier.scheduled, contains(rental.id));
    expect(notifier.scheduledEndingSoon, contains(rental.id));

    rig.activeRentalsCubit.openEnd(rental.id);
    rig.activeRentalsCubit.selectPayment(PaymentMethod.dinheiro);
    await rig.activeRentalsCubit.confirmEnd();
    expect(notifier.scheduled, isNot(contains(rental.id)));
    expect(notifier.scheduledEndingSoon, isNot(contains(rental.id)));
    rig.dispose();
  });

  test('a tempo corrido rental (spec 006) never schedules either notification', () async {
    final notifier = FakeRentalNotifier();
    final rig = RentalFlowRig(notifications: notifier);
    rig.newRentalCubit.setToy('cama');
    rig.newRentalCubit.setChildName('Sofia Teste Notif');
    rig.newRentalCubit.setOpenEnded(true);
    final rental = await rig.newRentalCubit.submit();

    expect(rental.isOpenEnded, isTrue);
    expect(notifier.scheduled, isEmpty);
    expect(notifier.scheduledEndingSoon, isEmpty);
    rig.dispose();
  });
}
