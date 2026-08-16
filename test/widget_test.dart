// Basic smoke test: the app boots and shows the home tab.

import 'package:flutter_test/flutter_test.dart';

import 'package:sonho_de_crianca/main.dart';

void main() {
  testWidgets('App boots on the home tab', (WidgetTester tester) async {
    await tester.pumpWidget(const SonhoDeCriancaApp());
    await tester.pump();

    expect(find.text('Sonho de Criança'), findsOneWidget);
    expect(find.text('Painel do dia'), findsOneWidget);
    expect(find.text('Nova locação'), findsOneWidget);
  });
}
