// Widget tests for spec 014 (migração — relatório) — first coverage this
// screen ever got. Confirms the migrated ReportView renders through the
// real app wiring (main.dart's providers) and that switching period
// updates what's on screen.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/ui/features/app_shell/view_models/app_shell_cubit.dart';
import 'package:sonho_de_crianca/ui/features/app_shell/view_models/app_shell_state.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  // Totals asserted below come from the demo seed (h1/h2/h3 finished
  // today) — spec 020-persistencia-local: the real app's default
  // RentalRepository starts empty, so this test asks for the seed
  // explicitly.
  await tester.pumpWidget(SonhoDeCriancaApp(rentalRepository: RentalRepository.withDemoSeed()));
  await tester.pump(const Duration(milliseconds: 400));
  // Navigation lives in AppShellCubit (spec 021-migracao-shell-app), not
  // AppState, since home_shell.dart/app_bottom_nav.dart/app_header.dart
  // stopped reading AppState.
  BlocProvider.of<AppShellCubit>(tester.element(find.byType(MaterialApp)), listen: false).setTab(AppTab.report);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  SharedPreferences.setMockInitialValues({});

  testWidgets('shows the period total and the payment/toy breakdown headers', (tester) async {
    await _pumpApp(tester);
    final scrollable = find.byType(Scrollable).first;

    expect(find.text('FATURADO NO PERÍODO'), findsOneWidget);
    // Default period is "Hoje" — h1/h2/h3 in the seed are finished today.
    expect(find.text('R\$ 35,00'), findsOneWidget);
    expect(find.text('POR FORMA DE PAGAMENTO'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('POR BRINQUEDO'), 200, scrollable: scrollable);
    expect(find.text('POR BRINQUEDO'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('HISTÓRICO'), 200, scrollable: scrollable);
    expect(find.text('HISTÓRICO'), findsOneWidget);
  });

  testWidgets('switching to "Tudo" grows the total to include every finished rental', (tester) async {
    await _pumpApp(tester);
    expect(find.text('R\$ 35,00'), findsOneWidget);

    await tester.tap(find.text('Tudo'));
    await tester.pump(const Duration(milliseconds: 300));

    // h1-h8 all count now (10+15+10+24+12+10+15+10 = 106).
    expect(find.text('R\$ 106,00'), findsOneWidget);
    expect(find.text('R\$ 35,00'), findsNothing);
  });
}
