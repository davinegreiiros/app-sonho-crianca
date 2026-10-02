// Widget tests for spec 027-login-admin-sessao: "Entrar como administrador"
// pede login só sem sessão válida (cenários 1/2), menu do administrador volta pros
// postos mantendo a sessão (cenário 5) ou sai da conta (cenário 4), e a
// ação "Entrar" de SnackBar não depende do `BuildContext` de quem a
// mostrou (cenário 9).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/auth_repository.dart';
import 'package:sonho_de_crianca/data/repositories/turno_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/domain/models/operator.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/test_keys.dart';
import 'package:sonho_de_crianca/widgets/auth_gate.dart';

import 'fakes/fake_auth_backend.dart';
import 'fakes/fake_rental_backend.dart';
import 'fakes/fake_session_storage.dart';
import 'fakes/fake_toy_backend.dart';

const _maria = Operator(id: 'op1', name: 'Maria Souza', username: 'maria');

ApiClient _loginApi() => ApiClient(
      httpClient: fakeLoginBackend(validUsername: 'maria', validPassword: 'segredo123', operatorOnSuccess: _maria),
    );

Future<void> _pumpApp(WidgetTester tester, AuthRepository authRepository, {bool startInAdmin = false}) async {
  await tester.pumpWidget(SonhoDeCriancaApp(
    authRepository: authRepository,
    toyRepository: fakeToyRepository(initial: kInitialToys, authRepository: authRepository),
    rentalRepository: fakeRentalRepository(authRepository: authRepository),
    turnoRepository: TurnoRepository(),
    startInPostoAdminMode: startInAdmin,
  ));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _settle(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openAdminMenuItem(WidgetTester tester, Key item) async {
  await tester.tap(find.byKey(TestKeys.adminMenuButton));
  await _settle(tester, frames: 4);
  await tester.tap(find.byKey(item));
  await _settle(tester);
}

void main() {
  setUp(setUpFakeSessionStorage);

  testWidgets('com sessão válida, "Entrar como administrador" entra direto (cenário 1)', (tester) async {
    final authRepository = AuthRepository.withSession(token: 'sessao-salva', operator: _maria, apiClient: _loginApi());
    await _pumpApp(tester, authRepository);

    await tester.tap(find.byKey(TestKeys.enterAdminButton));
    await _settle(tester);

    expect(find.byKey(TestKeys.loginUsernameField), findsNothing);
    expect(find.byKey(TestKeys.fabNewRental), findsOneWidget);
  });

  testWidgets('"Voltar para os postos" e entrar de novo não pede login', (tester) async {
    final authRepository = AuthRepository.withSession(token: 'sessao-salva', operator: _maria);
    await _pumpApp(tester, authRepository, startInAdmin: true);

    await _openAdminMenuItem(tester, TestKeys.adminBackToPostosItem);
    await tester.tap(find.byKey(TestKeys.enterAdminButton));
    await _settle(tester);

    expect(find.byKey(TestKeys.loginUsernameField), findsNothing);
    expect(find.byKey(TestKeys.fabNewRental), findsOneWidget);
  });

  testWidgets('sem sessão, "Entrar como administrador" pede login (cenário 1)', (tester) async {
    final authRepository = AuthRepository(apiClient: _loginApi());
    await _pumpApp(tester, authRepository);

    await tester.tap(find.byKey(TestKeys.enterAdminButton));
    await _settle(tester);

    expect(find.byKey(TestKeys.loginUsernameField), findsOneWidget);
    expect(find.byKey(TestKeys.fabNewRental), findsNothing);
  });

  testWidgets('"Voltar" no login continua na escolha de posto (cenário 2)', (tester) async {
    final authRepository = AuthRepository(apiClient: _loginApi());
    await _pumpApp(tester, authRepository);

    await tester.tap(find.byKey(TestKeys.enterAdminButton));
    await _settle(tester);
    await tester.tap(find.byKey(TestKeys.loginBackButton));
    await _settle(tester);

    expect(find.byKey(TestKeys.enterAdminButton), findsOneWidget);
    expect(find.byKey(TestKeys.fabNewRental), findsNothing);
  });

  testWidgets('login com sucesso entra no modo administrador com token novo', (tester) async {
    final authRepository = AuthRepository(apiClient: _loginApi());
    await _pumpApp(tester, authRepository);

    await tester.tap(find.byKey(TestKeys.enterAdminButton));
    await _settle(tester);
    await tester.enterText(find.byKey(TestKeys.loginUsernameField), 'maria');
    await tester.enterText(find.byKey(TestKeys.loginPasswordField), 'segredo123');
    await tester.tap(find.byKey(TestKeys.loginSubmitButton));
    await _settle(tester);

    expect(find.byKey(TestKeys.fabNewRental), findsOneWidget);
    expect(authRepository.token, 'fake-token');
  });

  testWidgets('"Voltar para os postos" mantém a sessão (cenário 5)', (tester) async {
    final authRepository = AuthRepository.withSession(token: 'sessao-salva', operator: _maria);
    await _pumpApp(tester, authRepository, startInAdmin: true);

    await _openAdminMenuItem(tester, TestKeys.adminBackToPostosItem);

    expect(find.byKey(TestKeys.enterAdminButton), findsOneWidget);
    expect(authRepository.isLoggedIn, isTrue);
  });

  testWidgets('"Sair da conta" confirma, apaga a sessão e volta pros postos (cenário 4)', (tester) async {
    final authRepository = AuthRepository(apiClient: _loginApi());
    await authRepository.login('maria', 'segredo123'); // grava no SharedPreferences
    await _pumpApp(tester, authRepository, startInAdmin: true);

    await _openAdminMenuItem(tester, TestKeys.adminLogoutItem);
    await tester.tap(find.byKey(TestKeys.adminLogoutConfirmButton));
    await _settle(tester);

    expect(find.byKey(TestKeys.enterAdminButton), findsOneWidget);
    expect(authRepository.isLoggedIn, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sonho_de_crianca_session'), isNull);
  });

  testWidgets('cancelar "Sair da conta" mantém tudo como estava', (tester) async {
    final authRepository = AuthRepository.withSession(token: 'sessao-salva', operator: _maria);
    await _pumpApp(tester, authRepository, startInAdmin: true);

    await _openAdminMenuItem(tester, TestKeys.adminLogoutItem);
    await tester.tap(find.text('Cancelar'));
    await _settle(tester);

    expect(find.byKey(TestKeys.fabNewRental), findsOneWidget);
    expect(authRepository.isLoggedIn, isTrue);
  });

  testWidgets('ação "Entrar" funciona depois que o sheet de origem fechou (cenário 9)', (tester) async {
    final authRepository = AuthRepository(apiClient: _loginApi());
    late VoidCallback loginAction;
    await tester.pumpWidget(ChangeNotifierProvider<AuthRepository>.value(
      value: authRepository,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (sheetContext) {
                  loginAction = loginActionFor(sheetContext);
                  return const SizedBox(height: 100, child: Text('sheet'));
                },
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('abrir'));
    await _settle(tester, frames: 5);
    Navigator.of(tester.element(find.text('sheet'))).pop();
    await _settle(tester, frames: 5);
    expect(find.text('sheet'), findsNothing); // contexto do sheet já desmontado

    loginAction();
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(TestKeys.loginUsernameField), findsOneWidget);
  });
}
