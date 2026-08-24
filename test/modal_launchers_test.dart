// Regression test for a real crash seen after spec 020 (persistência
// local): removing every toy from the catalog and then tapping the "+"
// FAB threw `Bad state: No element` — `NewRentalCubit._fresh` always
// picked *some* toy for the draft (`toys.firstWhere(..., orElse: () =>
// toys.first)`), which has no answer when `toys` is empty. Fixed in
// `showNewRentalSheet` (widgets/modal_launchers.dart), which now bails
// out with a message before the Cubit ever runs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/toy_repository.dart';
import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/test_keys.dart';
import 'package:sonho_de_crianca/ui/features/rental/views/new_rental_sheet_view.dart';

const _settle = Duration(milliseconds: 400);

void main() {
  SharedPreferences.setMockInitialValues({});

  testWidgets('tapping "+" with an empty catalog shows a message instead of crashing', (tester) async {
    await tester.pumpWidget(const SonhoDeCriancaApp());
    await tester.pump(_settle);

    // Empties the catalog mid-session (booting with an already-empty
    // ToyRepository would crash earlier still, in AppState's own seed —
    // out of scope here) through the same shared instance the app reads.
    final toyRepository = Provider.of<ToyRepository>(tester.element(find.byType(MaterialApp)), listen: false);
    for (final toy in List.of(toyRepository.toys)) {
      toyRepository.remove(toy.id);
    }
    await tester.pump(_settle);
    expect(toyRepository.toys, isEmpty);

    await tester.tap(find.byKey(TestKeys.fabNewRental));
    await tester.pump(_settle);

    expect(find.text('Cadastre um brinquedo no catálogo antes de registrar uma locação.'), findsOneWidget);
    expect(find.byType(NewRentalSheetView), findsNothing);
  });
}
