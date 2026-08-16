// End-to-end integration tests for the Sonho de Criança app.
//
// Run on a device/emulator:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart -d <device-id>
//
// Or directly with `flutter test` (native integration_test runner, no
// flutter_driver host needed) once a device is attached:
//   flutter test integration_test/app_test.dart -d <device-id>
//
// NOTE: the app has several *continuously repeating* animations (FAB
// bounce, header dots, timer stripes, overtime pulse) by design, so
// `pumpAndSettle()` — which waits for the frame scheduler to go idle —
// would hang/time out anywhere in this tree. Every settle point below
// uses a bounded `pump(duration)` instead. Widget/text finders still see
// everything regardless of animation progress (opacity/transform never
// remove a widget from the tree), so short bounded pumps are enough.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/test_keys.dart';

const _settle = Duration(milliseconds: 400);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sonho de Criança', () {
    testWidgets('boots on the home tab with today\'s numbers', (tester) async {
      await tester.pumpWidget(const SonhoDeCriancaApp());
      await tester.pump(_settle);

      expect(find.text('Sonho de Criança'), findsOneWidget);
      expect(find.text('Painel do dia'), findsOneWidget);
      expect(find.text('FATURADO HOJE'), findsOneWidget);
      expect(find.text('Nova locação'), findsWidgets);
    });

    testWidgets('bottom nav switches between all four tabs', (tester) async {
      await tester.pumpWidget(const SonhoDeCriancaApp());
      await tester.pump(_settle);

      await tester.tap(find.byKey(TestKeys.navActive));
      await tester.pump(_settle);
      expect(find.text('Em andamento'), findsOneWidget);

      await tester.tap(find.byKey(TestKeys.navCatalog));
      await tester.pump(_settle);
      expect(find.text('Brinquedos'), findsOneWidget);

      await tester.tap(find.byKey(TestKeys.navReport));
      await tester.pump(_settle);
      expect(find.text('Faturamento'), findsOneWidget);

      await tester.tap(find.byKey(TestKeys.navHome));
      await tester.pump(_settle);
      expect(find.text('Painel do dia'), findsOneWidget);
    });

    testWidgets('creates a rental, finishes it and sees it in history', (tester) async {
      await tester.pumpWidget(const SonhoDeCriancaApp());
      await tester.pump(_settle);

      const childName = 'Teste Integração';

      // Open the "Nova locação" sheet from the FAB.
      await tester.tap(find.byKey(TestKeys.fabNewRental));
      await tester.pump(_settle); // modal bottom sheet's own transition is finite

      await tester.enterText(find.byKey(TestKeys.draftChildNameField), childName);
      await tester.pump(); // let the enabled/disabled state of the submit button rebuild
      await tester.tap(find.byKey(TestKeys.submitNewRentalButton));
      await tester.pump(_settle);

      // Sheet closed, new rental shows up as active.
      expect(find.byKey(TestKeys.submitNewRentalButton), findsNothing);

      final appState = Provider.of<AppState>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      final rental = appState.rentals.firstWhere((r) => r.childName == childName);

      await tester.tap(find.byKey(TestKeys.navActive));
      await tester.pump(_settle);
      expect(find.byKey(TestKeys.activeCardKey(rental.id)), findsOneWidget);

      // Finish it, picking Pix as the payment method. Scroll it fully into
      // view first — it's the last card and can sit near the fixed FAB.
      await tester.ensureVisible(find.byKey(TestKeys.finishRentalButton(rental.id)));
      await tester.pump(_settle);
      await tester.tap(find.byKey(TestKeys.finishRentalButton(rental.id)));
      await tester.pump(_settle); // dialog pop-in transition

      await tester.tap(find.byKey(TestKeys.paymentOption('pix')));
      await tester.pump(_settle);
      await tester.tap(find.byKey(TestKeys.confirmEndButton));
      await tester.pump(_settle);

      // No longer active.
      expect(find.byKey(TestKeys.activeCardKey(rental.id)), findsNothing);
      expect(appState.rentals.firstWhere((r) => r.id == rental.id).status.name, 'done');

      // Shows up as done on the home tab's recent activity.
      await tester.tap(find.byKey(TestKeys.navHome));
      await tester.pump(_settle);
      expect(find.textContaining(childName), findsWidgets);
    });

    testWidgets('cancels an active rental', (tester) async {
      await tester.pumpWidget(const SonhoDeCriancaApp());
      await tester.pump(_settle);

      final appState = Provider.of<AppState>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      final before = appState.activeRentals.length;
      final target = appState.activeRentals.first;

      await tester.tap(find.byKey(TestKeys.navActive));
      await tester.pump(_settle);

      await tester.tap(find.byKey(TestKeys.cancelRentalButton(target.id)));
      await tester.pump(_settle);

      expect(appState.activeRentals.length, before - 1);
      expect(find.byKey(TestKeys.activeCardKey(target.id)), findsNothing);
    });

    testWidgets('report tab period selector switches totals', (tester) async {
      await tester.pumpWidget(const SonhoDeCriancaApp());
      await tester.pump(_settle);

      await tester.tap(find.byKey(TestKeys.navReport));
      await tester.pump(_settle);

      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('14 dias'), findsOneWidget);
      expect(find.text('Tudo'), findsOneWidget);

      await tester.tap(find.text('Tudo'));
      await tester.pump(_settle);
      expect(find.text('FATURADO NO PERÍODO'), findsOneWidget);
    });
  });
}
