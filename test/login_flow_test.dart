// Tests for spec 024-sync-backend-fundacao, cenário 8: `openBusinessSettingsScreen`
// é o único ponto de entrada em Configurações — sem sessão, sempre passa
// pelo login primeiro, não importa o caller (aqui: o gear icon do
// `app_header.dart`; o atalho de Pix em `end_rental_dialog_view.dart` usa a
// mesma função, sem guarda própria).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sonho_de_crianca/data/repositories/auth_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/domain/models/operator.dart';
import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/test_keys.dart';

import 'fakes/fake_auth_backend.dart';
import 'fakes/fake_business_settings.dart';
import 'fakes/fake_secure_storage.dart';

const _maria = Operator(id: 'op1', name: 'Maria Souza', username: 'maria');

Future<AppState> _pumpLoggedOutApp(WidgetTester tester) async {
  final authRepository = AuthRepository(
    apiClient: ApiClient(httpClient: fakeLoginBackend(validUsername: 'maria', validPassword: 'segredo123', operatorOnSuccess: _maria)),
  );
  await tester.pumpWidget(SonhoDeCriancaApp(
    authRepository: authRepository,
    businessSettingsRepository: fakeBusinessSettingsRepository(authRepository: authRepository),
    startInPostoAdminMode: true,
  ));
  await tester.pump(const Duration(milliseconds: 400));
  return Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);
}

Future<void> _settleFrames(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(setUpFakeSecureStorage);

  testWidgets('sem sessão: gear icon abre login, não Configurações', (tester) async {
    await _pumpLoggedOutApp(tester);

    await tester.tap(find.byKey(TestKeys.settingsGearButton));
    await _settleFrames(tester);

    expect(find.byKey(TestKeys.loginUsernameField), findsOneWidget);
    expect(find.byKey(TestKeys.businessNameField), findsNothing);
  });

  testWidgets('login com sucesso segue pra Configurações depois do gear icon', (tester) async {
    await _pumpLoggedOutApp(tester);

    await tester.tap(find.byKey(TestKeys.settingsGearButton));
    await _settleFrames(tester);

    await tester.enterText(find.byKey(TestKeys.loginUsernameField), 'maria');
    await tester.enterText(find.byKey(TestKeys.loginPasswordField), 'segredo123');
    await tester.tap(find.byKey(TestKeys.loginSubmitButton));
    await _settleFrames(tester);

    expect(find.byKey(TestKeys.businessNameField), findsOneWidget);
  });

  testWidgets('senha errada: mensagem de erro, continua na tela de login', (tester) async {
    await _pumpLoggedOutApp(tester);

    await tester.tap(find.byKey(TestKeys.settingsGearButton));
    await _settleFrames(tester);

    await tester.enterText(find.byKey(TestKeys.loginUsernameField), 'maria');
    await tester.enterText(find.byKey(TestKeys.loginPasswordField), 'errada');
    await tester.tap(find.byKey(TestKeys.loginSubmitButton));
    await _settleFrames(tester);

    expect(find.byKey(TestKeys.loginErrorText), findsOneWidget);
    expect(find.byKey(TestKeys.businessNameField), findsNothing);
  });

  testWidgets('cancelar login (voltar) nunca chega a abrir Configurações', (tester) async {
    await _pumpLoggedOutApp(tester);

    await tester.tap(find.byKey(TestKeys.settingsGearButton));
    await _settleFrames(tester);

    await tester.tap(find.byKey(TestKeys.loginBackButton));
    await _settleFrames(tester);

    expect(find.byKey(TestKeys.loginUsernameField), findsNothing);
    expect(find.byKey(TestKeys.businessNameField), findsNothing);
  });
}
