// Basic smoke test: the app boots and shows the home tab.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/main.dart';

void main() {
  // AppState() loads business Pix settings via SharedPreferences (spec
  // 004) — mock it so that hits the in-memory fake instead of a real
  // platform channel with nothing listening on the other end.
  SharedPreferences.setMockInitialValues({});

  testWidgets('App boots on the home tab', (WidgetTester tester) async {
    await tester.pumpWidget(const SonhoDeCriancaApp());
    await tester.pump();

    expect(find.text('Sonho de Criança'), findsOneWidget);
    expect(find.text('Painel do dia'), findsOneWidget);
    expect(find.text('Nova locação'), findsOneWidget);
  });
}
