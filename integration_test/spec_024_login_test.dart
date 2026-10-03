// T20 (spec 024-sync-backend-fundacao) — smoke-test de verdade: nenhum
// mock, bate no backend real em produção (https://sonho-de-crianca-backend.vercel.app).
// Precisa de device/emulador real (`flutter test integration_test/spec_024_login_test.dart
// -d <device-id>`) — web não é suportado pelo `integration_test`.
//
// Credenciais: um operador de teste ativo, via `--dart-define-from-file=secrets.json`
// (`T20_USERNAME`/`T20_PASSWORD`, ver `secrets.example.json`) — nunca no código.
// Sem elas o teste é pulado. Criar/reativar o operador no painel do backend
// (`/painel`) e desativar de novo depois de rodar.
//
// Atenção: o passo 4 grava `BusinessSettings` de verdade (nome, cidade, chave
// Pix) no backend de produção. Com cliente usando o app, rodar só contra um
// backend de teste (`--dart-define=API_BASE_URL=...`) ou restaurar os valores
// reais logo depois.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/test_keys.dart';

const _settle = Duration(milliseconds: 500);
const _username = String.fromEnvironment('T20_USERNAME');
const _password = String.fromEnvironment('T20_PASSWORD');

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
    await tester.enterText(find.byKey(TestKeys.loginUsernameField), _username);
    await tester.enterText(find.byKey(TestKeys.loginPasswordField), 'senha-errada-de-proposito');
    await tester.pump();
    await tester.tap(find.byKey(TestKeys.loginSubmitButton));
    await _waitUntil(tester, () => find.byKey(TestKeys.loginErrorText).evaluate().isNotEmpty);
    expect(find.byKey(TestKeys.loginErrorText), findsOneWidget);

    // 3. Credenciais corretas -> segue pra Configurações de verdade.
    await tester.enterText(find.byKey(TestKeys.loginPasswordField), _password);
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

    // 5. Reabre — sessão persistida localmente (SharedPreferences real
    // neste device, spec 027), não pede login de novo; mostra o valor que acabou de
    // salvar, vindo do backend de verdade.
    await tester.tap(find.byKey(TestKeys.settingsGearButton));
    await _waitUntil(tester, () => find.byKey(TestKeys.businessNameField).evaluate().isNotEmpty);
    expect(find.byKey(TestKeys.loginUsernameField), findsNothing); // não pediu login de novo
    expect(find.text('Sonho de Criança (smoke T20)'), findsOneWidget);
  }, skip: _username.isEmpty || _password.isEmpty);
}
