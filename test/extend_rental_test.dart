// Tests for spec 008 (adicionar tempo e alarme visual): extending an
// active fixed-duration rental adds minutes and proportional price, and
// reschedules both its end notification and its "5 minutes left"
// heads-up (spec 009); a tempo corrido (spec 006) rental is untouched by
// it, since it has no fixed duration to extend.
//
// Migrado na spec 026-rental-via-backend: `AppState.submitNew`/
// `extendActive` foram removidos (ver `RentalFlowRig`) — aciona
// `NewRentalCubit`/`ActiveRentalsCubit` direto, os Cubits reais que a UI
// usa desde as specs 017/018.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_rental_notifier.dart';
import 'fakes/rental_flow_rig.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  test('extendActive adds minutes and proportional price, reschedules notification', () async {
    final notifier = FakeRentalNotifier();
    final rig = RentalFlowRig(notifications: notifier);
    rig.newRentalCubit.setToy('cama'); // blockMin 30, price 15 -> R$0,50/min
    rig.newRentalCubit.setChildName('Sofia Teste Extend');
    rig.newRentalCubit.applyDuration(15); // price = round(15 * 15/30) = 8
    final rental = await rig.newRentalCubit.submit();

    expect(rental.durationMin, 15);
    expect(rental.price, 8);
    final originalSchedule = notifier.scheduled[rental.id];
    final originalSoonSchedule = notifier.scheduledEndingSoon[rental.id];
    expect(originalSchedule, rental.startedAt.add(const Duration(minutes: 15)));
    expect(originalSoonSchedule, rental.startedAt.add(const Duration(minutes: 10)));

    await rig.activeRentalsCubit.extendActive(rental.id, 10);

    expect(rental.durationMin, 25);
    expect(rental.price, 13); // 8 + 0.5/min * 10min
    expect(notifier.scheduled[rental.id], rental.startedAt.add(const Duration(minutes: 25)));
    expect(notifier.scheduled[rental.id], isNot(originalSchedule));
    expect(notifier.scheduledEndingSoon[rental.id], rental.startedAt.add(const Duration(minutes: 20)));
    expect(notifier.scheduledEndingSoon[rental.id], isNot(originalSoonSchedule));
    rig.dispose();
  });

  test('extendActive is a no-op on a tempo corrido (open-ended) rental', () async {
    final notifier = FakeRentalNotifier();
    final rig = RentalFlowRig(notifications: notifier);
    rig.newRentalCubit.setToy('cama');
    rig.newRentalCubit.setChildName('Sofia Teste Extend Aberta');
    rig.newRentalCubit.setOpenEnded(true);
    final rental = await rig.newRentalCubit.submit();

    expect(rental.isOpenEnded, isTrue);
    final priceBefore = rental.price;

    await rig.activeRentalsCubit.extendActive(rental.id, 10);

    expect(rental.durationMin, isNull);
    expect(rental.price, priceBefore);
    expect(notifier.scheduled, isEmpty);
    expect(notifier.scheduledEndingSoon, isEmpty);
    rig.dispose();
  });
}
