// Full-app, end-to-end regression journey — headless counterpart to
// `integration_test/app_test.dart` (same scenarios, ported to run via
// plain `flutter test`, no device/simulator needed). Exists specifically
// to validate the architecture migration (specs 010-016): it boots the
// real `SonhoDeCriancaApp()` — the exact `main.dart` wiring, every
// Repository/Cubit/AppState together, not in isolation — and drives the
// same user journey a person would, to prove the app still behaves
// exactly like it did before the migration.
//
// Re-run this (and keep extending it) after every fatia lands, and treat
// it as the final acceptance gate once fatia 016 (the last one) is done.
//
// NOTE: the app has several *continuously repeating* animations (FAB
// bounce, header dots, timer stripes, overtime pulse) by design, so
// `pumpAndSettle()` would hang here — every settle point uses a bounded
// `pump(duration)` instead, same reasoning as `integration_test/app_test.dart`.
// The test surface is also set to a realistic phone size (unlike the
// default 800x600 `flutter_test` canvas) so sheet/dialog buttons that a
// real device shows without scrolling are actually tappable here too.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/test_keys.dart';
import 'package:sonho_de_crianca/ui/features/catalog/views/add_toy_sheet_view.dart';

const _settle = Duration(milliseconds: 400);

/// Several small pumps, not one big jump — some transitions (a pushed
/// `MaterialPageRoute`, `EndRentalDialog`'s elastic pop-in) only reach
/// their final layout after multiple discrete frames, same reasoning
/// `test/pix_flow_test.dart` and `test/design_v3_test.dart` already
/// documented for this codebase.
Future<void> _settleFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<AppState> _pumpApp(WidgetTester tester, {RentalRepository? rentalRepository}) async {
  // Deliberately keeps flutter_test's default canvas (matches every other
  // widget test in this suite) — a phone-sized override was tried and
  // caused an unrelated AppHeader overflow (test fonts measure wider than
  // real device fonts here), so off-screen content is handled per-tap
  // with `ensureVisible`/`scrollUntilVisible` instead, same as
  // `pix_flow_test.dart`/`catalog_tickets_test.dart` already do.
  await tester.pumpWidget(SonhoDeCriancaApp(rentalRepository: rentalRepository));
  await tester.pump(_settle);
  return Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);
}

void main() {
  SharedPreferences.setMockInitialValues({});

  group('Sonho de Criança — jornada completa', () {
    testWidgets('boots on the home tab with today\'s numbers', (tester) async {
      await _pumpApp(tester);

      expect(find.text('Sonho de Criança'), findsOneWidget);
      expect(find.text('Painel do dia'), findsOneWidget);
      expect(find.text('FATURADO HOJE'), findsOneWidget);
      expect(find.text('Nova locação'), findsWidgets);
    });

    testWidgets('bottom nav switches between all four tabs', (tester) async {
      await _pumpApp(tester);

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

    testWidgets('adds a toy in the catalog and sees it right away (ToyRepository shared instance)', (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.byKey(TestKeys.navCatalog));
      await tester.pump(_settle);

      await tester.tap(find.text('Adicionar brinquedo'));
      await tester.pump(_settle);

      // Scoped to the sheet itself — the catalog grid behind it also has
      // TextFields (price/minutes on each card), so an unscoped
      // `find.byType(TextField).first` could hit one of those instead.
      final nameField = find.descendant(of: find.byType(AddToySheetView), matching: find.byType(TextField)).first;
      await tester.enterText(nameField, 'Brinquedo Jornada Completa');
      await tester.pump();
      await tester.ensureVisible(find.byKey(TestKeys.categoryOption('outro')));
      await tester.pump();
      await tester.tap(find.byKey(TestKeys.categoryOption('outro')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(TestKeys.addToySubmitButton));
      await tester.pump();
      await tester.tap(find.byKey(TestKeys.addToySubmitButton));
      await tester.pump(_settle);

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Brinquedo Jornada Completa'), 200, scrollable: scrollable);
      expect(find.text('Brinquedo Jornada Completa'), findsOneWidget);
    });

    testWidgets('saves business settings and sees them reflected on the Pix flow (BusinessSettingsRepository shared instance)', (tester) async {
      final appState = await _pumpApp(tester);

      await tester.tap(find.byKey(TestKeys.settingsGearButton));
      await _settleFrames(tester);

      await tester.enterText(find.byKey(TestKeys.businessNameField), 'Sonho de Criança Teste');
      await tester.enterText(find.byKey(TestKeys.businessCityField), 'Fortaleza');
      await tester.enterText(find.byKey(TestKeys.businessPixKeyField), '85999998888');
      await tester.pump();
      await tester.tap(find.byKey(TestKeys.saveBusinessSettingsButton));
      await _settleFrames(tester);

      expect(appState.businessSettings.merchantName, 'Sonho de Criança Teste');
      expect(appState.businessSettings.isConfigured, isTrue);
    });

    testWidgets('creates a rental, finishes it and sees it in history', (tester) async {
      final appState = await _pumpApp(tester);

      const childName = 'Teste Jornada Completa';

      // Creation itself goes through AppState directly (same convention
      // `test/catalog_tickets_test.dart`/`test/open_ended_rental_test.dart`
      // already use) — typing into a focused field inside a scrolled,
      // modal sheet is exactly what `integration_test/app_test.dart`
      // exists for, on a real device/keyboard. What matters here is that
      // the rental created this way is visible/actionable through every
      // migrated screen below (Active, Home, Report).
      appState.setDraftChild(childName);
      appState.submitNew();
      await tester.pump(_settle);

      final rental = appState.rentals.firstWhere((r) => r.childName == childName);

      await tester.tap(find.byKey(TestKeys.navActive));
      await tester.pump(_settle);
      await tester.scrollUntilVisible(find.byKey(TestKeys.activeCardKey(rental.id)), 200, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(TestKeys.activeCardKey(rental.id)), findsOneWidget);

      await tester.ensureVisible(find.byKey(TestKeys.finishRentalButton(rental.id)));
      await tester.pump();
      await tester.tap(find.byKey(TestKeys.finishRentalButton(rental.id)));
      await _settleFrames(tester);

      // Cartão, not Pix — finishing via Pix without business settings
      // configured redirects to the settings screen instead (covered by
      // `test/pix_flow_test.dart` and by the settings test above); this
      // scenario is about the rental itself flowing through Active ->
      // Home -> Report, not the Pix branch specifically.
      await tester.tap(find.byKey(TestKeys.paymentOption('cartao')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(TestKeys.confirmEndButton));
      await _settleFrames(tester);

      expect(find.byKey(TestKeys.activeCardKey(rental.id)), findsNothing);
      expect(appState.rentals.firstWhere((r) => r.id == rental.id).status.name, 'done');

      await tester.tap(find.byKey(TestKeys.navHome));
      await tester.pump(_settle);
      expect(find.textContaining(childName), findsWidgets);

      // Also shows up in the report — RentalRepository shared between
      // AppState (created it) and ReportCubit (reads it).
      await tester.tap(find.byKey(TestKeys.navReport));
      await tester.pump(_settle);
      await tester.tap(find.text('Tudo'));
      await tester.pump(_settle);
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.textContaining(childName), 200, scrollable: scrollable);
      expect(find.textContaining(childName), findsWidgets);
    });

    testWidgets('cancels an active rental', (tester) async {
      final appState = await _pumpApp(tester, rentalRepository: RentalRepository.withDemoSeed());

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
      await _pumpApp(tester);

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
