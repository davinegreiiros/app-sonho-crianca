// Widget tests for spec 007 (Revisão de Design v3): category icons, the
// tempo-corrido CTA label, and Configurações opening as a full screen
// instead of a bottom sheet.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/test_keys.dart';
import 'package:sonho_de_crianca/ui/features/app_shell/view_models/app_shell_cubit.dart';
import 'package:sonho_de_crianca/widgets/category_icon.dart';

Future<AppState> _pumpApp(WidgetTester tester, {RentalRepository? rentalRepository}) async {
  await tester.pumpWidget(SonhoDeCriancaApp(rentalRepository: rentalRepository));
  await tester.pump(const Duration(milliseconds: 400));
  return Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);
}

// Navigation lives in AppShellCubit (spec 021-migracao-shell-app), not
// AppState, since home_shell.dart stopped reading AppState.
void _setTab(WidgetTester tester, AppTab tab) {
  BlocProvider.of<AppShellCubit>(tester.element(find.byType(MaterialApp)), listen: false).setTab(tab);
}

void main() {
  SharedPreferences.setMockInitialValues({});

  testWidgets('catalog card shows the right category icon', (tester) async {
    await _pumpApp(tester);
    _setTab(tester, AppTab.catalog);
    await tester.pump(const Duration(milliseconds: 400));

    // Seed: 'carrinho' is ToyCategory.eletrico.
    final card = find.byKey(TestKeys.toyCardKey('carrinho'));
    final icon = tester.widget<CategoryIcon>(find.descendant(of: card, matching: find.byType(CategoryIcon)));
    expect(icon.category, ToyCategory.eletrico);
  });

  testWidgets('tempo-corrido active card says "Parar e cobrar", fixed-duration says "Finalizar"', (tester) async {
    final state = await _pumpApp(tester, rentalRepository: RentalRepository.withDemoSeed());

    state.openNew();
    state.setDraftToy('cama');
    state.setDraftChild('Tempo Corrido Teste');
    state.setDraftOpenEnded(true);
    state.submitNew();
    final openEnded = state.rentals.firstWhere((r) => r.childName == 'Tempo Corrido Teste');

    _setTab(tester, AppTab.active);
    await tester.pump(const Duration(milliseconds: 400));

    final openEndedCard = find.byKey(TestKeys.activeCardKey(openEnded.id));
    await tester.scrollUntilVisible(openEndedCard, 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(find.descendant(of: openEndedCard, matching: find.text('Parar e cobrar')), findsOneWidget);

    // Seed rental 'a1' has a fixed duration (spec 006 unaffected).
    final fixedCard = find.byKey(TestKeys.activeCardKey('a1'));
    await tester.scrollUntilVisible(fixedCard, -200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(find.descendant(of: fixedCard, matching: find.text('Finalizar')), findsOneWidget);
  });

  testWidgets('gear icon opens Configurações as a full screen, not a bottom sheet', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(TestKeys.settingsGearButton));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byKey(TestKeys.businessNameField), findsOneWidget);
    expect(find.byKey(TestKeys.settingsScreenBackButton), findsOneWidget);
    // A `showModalBottomSheet` puts its content in a `Material` with a
    // `BottomSheet` ancestor; a pushed `MaterialPageRoute` doesn't.
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.byKey(TestKeys.settingsScreenBackButton));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(TestKeys.businessNameField), findsNothing);
  });
}
