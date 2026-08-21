// Tests for spec 006 (locação em tempo corrido): price calculation and the
// create/finish/cancel flow for a rental with no fixed duration.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/models/rental.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/test_keys.dart';

void main() {
  // AppState() kicks off an un-awaited SharedPreferences.getInstance() call
  // (business Pix settings, spec 004) — without this, that hits a real
  // platform channel with no test binding registered and throws async,
  // which flutter_test then blames on whatever test happens to be running.
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('AppState.computeFinalPrice', () {
    test('22 minutes on a R\$0,50/min toy (Cama Elástica) charges R\$11,00', () {
      final state = AppState();
      final camaElastica = state.toyById('cama'); // blockMin 30, price 15 -> 0.50/min
      expect(state.ratePerMinute(camaElastica), 0.5);

      final rental = Rental(
        id: 'x1',
        toyId: 'cama',
        childName: 'Teste',
        guardianName: '—',
        startedAt: DateTime.now().subtract(const Duration(minutes: 22)),
        durationMin: null, // open-ended
        price: 0,
        status: RentalStatus.active,
      );

      expect(state.computeFinalPrice(rental), 11.0);
      state.dispose();
    });

    test('a non-trivial fraction (22min37s) rounds only the final price to the cent', () {
      final state = AppState();
      final rental = Rental(
        id: 'x2',
        toyId: 'cama', // 0.50/min
        childName: 'Teste',
        guardianName: '—',
        startedAt: DateTime.now().subtract(const Duration(minutes: 22, seconds: 37)),
        durationMin: null,
        price: 0,
        status: RentalStatus.active,
      );

      // 22 + 37/60 = 22.6166...min * 0.5 = 11.3083... -> rounds to 11.31.
      expect(state.computeFinalPrice(rental), 11.31);
      state.dispose();
    });

    test('a fixed-duration rental is untouched — returns its own price as-is', () {
      final state = AppState();
      final rental = Rental(
        id: 'x3',
        toyId: 'cama',
        childName: 'Teste',
        guardianName: '—',
        startedAt: DateTime.now().subtract(const Duration(minutes: 99)),
        durationMin: 30,
        price: 15,
        status: RentalStatus.active,
      );

      expect(state.computeFinalPrice(rental), 15);
      state.dispose();
    });
  });

  group('open-ended rental flow', () {
    testWidgets('creating, then finishing, an open-ended rental charges the computed price', (tester) async {
      await tester.pumpWidget(const SonhoDeCriancaApp());
      await tester.pump(const Duration(milliseconds: 400));
      final state = Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);

      state.openNew();
      state.setDraftToy('cama'); // 0.50/min
      state.setDraftChild('Aberta');
      state.setDraftOpenEnded(true);
      state.submitNew();

      final rental = state.rentals.firstWhere((r) => r.childName == 'Aberta');
      expect(rental.isOpenEnded, isTrue);
      expect(rental.durationMin, isNull);
      expect(rental.price, 0); // placeholder until finished

      // Back-date the start so there's a deterministic elapsed time to
      // charge for, instead of asserting against a near-zero duration.
      final backdated = Rental(
        id: rental.id,
        toyId: rental.toyId,
        childName: rental.childName,
        guardianName: rental.guardianName,
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        durationMin: null,
        price: 0,
        status: RentalStatus.active,
      );
      final index = state.rentals.indexWhere((r) => r.id == rental.id);
      state.rentals[index] = backdated;

      state.openEnd(rental.id);
      state.selectPayment(PaymentMethod.pix);
      state.confirmEnd();

      final finished = state.rentals.firstWhere((r) => r.id == rental.id);
      expect(finished.status, RentalStatus.done);
      expect(finished.price, 5.0); // 10min * 0.50/min
    });

    testWidgets('cancelling an open-ended rental charges nothing', (tester) async {
      await tester.pumpWidget(const SonhoDeCriancaApp());
      await tester.pump(const Duration(milliseconds: 400));
      final state = Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);

      state.openNew();
      state.setDraftToy('cama');
      state.setDraftChild('Cancelada');
      state.setDraftOpenEnded(true);
      state.submitNew();

      final rental = state.rentals.firstWhere((r) => r.childName == 'Cancelada');
      state.cancelActive(rental.id);

      expect(state.rentals.any((r) => r.id == rental.id), isFalse);
    });

    testWidgets('"Nova locação" sheet toggles to tempo corrido and hides duration/price fields', (tester) async {
      await tester.pumpWidget(const SonhoDeCriancaApp());
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(TestKeys.fabNewRental));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('10min'), findsOneWidget); // fixed-duration presets shown by default

      // The sheet's own SingleChildScrollView shrink-wraps its content, so
      // `ensureVisible`/`scrollUntilVisible` (which compare against that
      // scrollable's own viewport) think everything is already visible
      // even when it's below the actual screen bounds — drag it manually.
      await tester.drag(find.byKey(TestKeys.draftChildNameField), const Offset(0, -300), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(TestKeys.rentalModeOpenEnded));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('10min'), findsNothing); // presets hidden in tempo corrido
      expect(find.textContaining('/min'), findsOneWidget);
    });
  });
}
