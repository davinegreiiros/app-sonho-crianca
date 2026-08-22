// Widget tests for spec 008 (adicionar tempo e alarme visual): the "+
// tempo" chips only show on a fixed-duration active card, and the overtime
// alarm icon only shows once a fixed-duration rental has run past its
// duration.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/models/rental.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/test_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('"+ tempo" chips show on a fixed-duration card and extend it on tap', (tester) async {
    await tester.pumpWidget(const SonhoDeCriancaApp());
    await tester.pump(const Duration(milliseconds: 400));
    final state = Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);

    state.openNew();
    state.setDraftToy('cama'); // blockMin 30, price 15 -> 0.50/min
    state.setDraftChild('Fixo Extend');
    state.applyDuration(15); // price = round(15 * 15/30) = 8
    state.submitNew();
    final rental = state.rentals.firstWhere((r) => r.childName == 'Fixo Extend');

    await tester.tap(find.byKey(TestKeys.navActive));
    await tester.pump(const Duration(milliseconds: 400));

    final chip = find.byKey(TestKeys.extendRentalButton(rental.id, 10));
    await tester.scrollUntilVisible(chip, 200, scrollable: find.byType(Scrollable).first);

    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 400));

    final extended = state.rentals.firstWhere((r) => r.id == rental.id);
    expect(extended.durationMin, 25);
    expect(extended.price, 13); // 8 + 0.50/min * 10min
  });

  testWidgets('"+ tempo" chips are absent on a tempo corrido (open-ended) card', (tester) async {
    await tester.pumpWidget(const SonhoDeCriancaApp());
    await tester.pump(const Duration(milliseconds: 400));
    final state = Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);

    state.openNew();
    state.setDraftToy('cama');
    state.setDraftChild('Aberta Extend');
    state.setDraftOpenEnded(true);
    state.submitNew();
    final rental = state.rentals.firstWhere((r) => r.childName == 'Aberta Extend');

    await tester.tap(find.byKey(TestKeys.navActive));
    await tester.pump(const Duration(milliseconds: 400));

    final card = find.byKey(TestKeys.activeCardKey(rental.id));
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(TestKeys.extendRentalButton(rental.id, 10)), findsNothing);
  });

  testWidgets('overtime alarm icon shows once a fixed-duration rental runs past its time', (tester) async {
    await tester.pumpWidget(const SonhoDeCriancaApp());
    await tester.pump(const Duration(milliseconds: 400));
    final state = Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);

    state.openNew();
    state.setDraftToy('cama');
    state.setDraftChild('Estourada');
    state.applyDuration(10);
    state.submitNew();
    final rental = state.rentals.firstWhere((r) => r.childName == 'Estourada');

    // Not yet overtime.
    await tester.tap(find.byKey(TestKeys.navActive));
    await tester.pump(const Duration(milliseconds: 400));
    final card = find.byKey(TestKeys.activeCardKey(rental.id));
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    expect(card, findsOneWidget);
    // Scoped to this card — the seeded data has another rental already in
    // overtime, so an unscoped `find.byIcon` would false-positive on it.
    final alarmIcon = find.descendant(of: card, matching: find.byIcon(Icons.notifications_active_rounded));
    expect(alarmIcon, findsNothing);

    // Back-date the start past the 10min duration.
    final index = state.rentals.indexWhere((r) => r.id == rental.id);
    state.rentals[index] = Rental(
      id: rental.id,
      toyId: rental.toyId,
      childName: rental.childName,
      guardianName: rental.guardianName,
      startedAt: DateTime.now().subtract(const Duration(minutes: 12)),
      durationMin: 10,
      price: rental.price,
      status: RentalStatus.active,
    );
    state.setTab(state.tab); // notifyListeners via a harmless no-op state change
    await tester.pump(const Duration(milliseconds: 400));

    expect(alarmIcon, findsOneWidget);
  });
}
