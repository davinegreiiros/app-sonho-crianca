// T20 (spec 024-sync-backend-fundacao) — smoke-test de verdade: nenhum
// mock, bate no backend real em produção (https://sonho-de-crianca-backend.vercel.app).
// Precisa de device/emulador real (`flutter test integration_test/spec_024_login_test.dart
// -d <device-id>`) — web não é suportado pelo `integration_test`.
//
// Credenciais: operador `t20smoke` seedado via `npm run seed:operator` no
// repo backend, só pra este smoke-test.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/test_keys.dart';

const _settle = Duration(milliseconds: 500);

/// Pumps generosos — é rede real (Vercel + Atlas), não um `MockClient`
/// instantâneo. Poll em vez de contar frames no chute, mesmo racional dos
/// testes mockados (`design_v3_test.dart`), só que com mais tempo de
/// parede por chamada.
Future<void> _waitUntil(WidgetTester tester, bool Function() condition, {int maxTries = 40}) async {
  for (var i = 0; i < maxTries && !condition(); i++) {
    await tester.pump(_settle);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T20 — login real (senha errada e certa) + Configurações via backend', (tester) async {
    await tester.pumpWidget(const SonhoDeCriancaApp(startInPostoAdminMode: true));
    await tester.pump(_settle);

    // 1. Sem sessão: gear icon abre login, não Configurações.
    await tester.tap(find.byKey(TestKeys.settingsGearButton));
    await _waitUntil(tester, () => find.byKey(TestKeys.loginUsernameField).evaluate().isNotEmpty);
    expect(find.byKey(TestKeys.loginUsernameField), findsOneWidget);
    expect(find.byKey(TestKeys.businessNameField), findsNothing);

    // 2. Senha errada -> erro específico de credencial, continua na tela.
    await tester.enterText(find.byKey(TestKeys.loginUsernameField), 't20smoke');
    await tester.enterText(find.byKey(TestKeys.loginPasswordField), 'senha-errada-de-proposito');
    await tester.pump();
    await tester.tap(find.byKey(TestKeys.loginSubmitButton));
    await _waitUntil(tester, () => find.byKey(TestKeys.loginErrorText).evaluate().isNotEmpty);
    expect(find.byKey(TestKeys.loginErrorText), findsOneWidget);

    // 3. Credenciais corretas -> segue pra Configurações de verdade.
    await tester.enterText(find.byKey(TestKeys.loginPasswordField), 'T20Smoke!2026');
    await tester.pump();
    await tester.tap(find.byKey(TestKeys.loginSubmitButton));
    await _waitUntil(tester, () => find.byKey(TestKeys.businessNameField).evaluate().isNotEmpty);
    expect(find.byKey(TestKeys.businessNameField), findsOneWidget);

    // 4. Salva de verdade (PUT real no backend) — sem travar, sem banner de erro.
    await tester.enterText(find.byKey(TestKeys.businessNameField), 'Sonho de Criança (smoke T20)');
    await tester.enterText(find.byKey(TestKeys.businessCityField), 'Fortaleza');
    await tester.enterText(find.byKey(TestKeys.businessPixKeyField), '85999998888');
    await tester.pump();
    await tester.tap(find.byKey(TestKeys.saveBusinessSettingsButton));
    await _waitUntil(tester, () => find.byKey(TestKeys.businessNameField).evaluate().isEmpty);
    expect(find.byKey(TestKeys.businessNameField), findsNothing); // fechou == salvou

    // 5. Reabre — sessão persistida localmente (flutter_secure_storage real
    // neste device), não pede login de novo; mostra o valor que acabou de
    // salvar, vindo do backend de verdade.
    await tester.tap(find.byKey(TestKeys.settingsGearButton));
    await _waitUntil(tester, () => find.byKey(TestKeys.businessNameField).evaluate().isNotEmpty);
    expect(find.byKey(TestKeys.loginUsernameField), findsNothing); // não pediu login de novo
    expect(find.text('Sonho de Criança (smoke T20)'), findsOneWidget);
  });
}
