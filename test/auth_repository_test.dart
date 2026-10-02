// Tests for spec 024-sync-backend-fundacao — AuthRepository: login
// ok/errado, sessão persiste e sobrevive "restart" (nova instância lendo o
// mesmo storage), logout limpa, erro de rede é distinto de credencial.
// Spec 027-login-admin-sessao: storage em `SharedPreferences`, JWT
// vencido nunca conta como logado.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/auth_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/data/services/api_exceptions.dart';
import 'package:sonho_de_crianca/domain/models/operator.dart';

import 'fakes/fake_auth_backend.dart';
import 'fakes/fake_session_storage.dart';

const _maria = Operator(id: 'op1', name: 'Maria Souza', username: 'maria');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setUpFakeSessionStorage);

  test('login com credenciais corretas guarda token/operator e notifica', () async {
    final repository = AuthRepository(
      apiClient: ApiClient(httpClient: fakeLoginBackend(validUsername: 'maria', validPassword: 'segredo123', operatorOnSuccess: _maria)),
    );
    var notified = false;
    repository.addListener(() => notified = true);

    await repository.login('maria', 'segredo123');

    expect(repository.isLoggedIn, isTrue);
    expect(repository.token, 'fake-token');
    expect(repository.currentOperator?.username, 'maria');
    expect(notified, isTrue);
  });

  test('login com senha errada lança ApiUnauthorizedException e não altera sessão', () async {
    final repository = AuthRepository(
      apiClient: ApiClient(httpClient: fakeLoginBackend(validUsername: 'maria', validPassword: 'segredo123', operatorOnSuccess: _maria)),
    );

    await expectLater(
      () => repository.login('maria', 'errada'),
      throwsA(isA<ApiUnauthorizedException>()),
    );
    expect(repository.isLoggedIn, isFalse);
  });

  test('login sem conexão lança ApiNetworkException', () async {
    final repository = AuthRepository(apiClient: ApiClient(httpClient: fakeUnreachableBackend()));

    await expectLater(() => repository.login('maria', 'segredo123'), throwsA(isA<ApiNetworkException>()));
  });

  test('sessão persiste e sobrevive "restart" — nova instância lê o mesmo storage', () async {
    final repository = AuthRepository(
      apiClient: ApiClient(httpClient: fakeLoginBackend(validUsername: 'maria', validPassword: 'segredo123', operatorOnSuccess: _maria)),
    );
    await repository.login('maria', 'segredo123');

    // "Restart": instância nova, sem nenhum estado em memória, mesmo
    // storage (mock de canal é global por teste) — como o app faria no
    // boot (`main.dart`, `restoreSession()`).
    final afterRestart = AuthRepository();
    expect(afterRestart.isLoggedIn, isFalse);
    await afterRestart.restoreSession();

    expect(afterRestart.isLoggedIn, isTrue);
    expect(afterRestart.token, 'fake-token');
    expect(afterRestart.currentOperator?.username, 'maria');
  });

  test('logout limpa a sessão em memória e no storage', () async {
    final repository = AuthRepository(
      apiClient: ApiClient(httpClient: fakeLoginBackend(validUsername: 'maria', validPassword: 'segredo123', operatorOnSuccess: _maria)),
    );
    await repository.login('maria', 'segredo123');

    await repository.logout();
    expect(repository.isLoggedIn, isFalse);

    final afterRestart = AuthRepository();
    await afterRestart.restoreSession();
    expect(afterRestart.isLoggedIn, isFalse);
  });

  test('sessão fica salva em SharedPreferences (spec 027)', () async {
    final repository = AuthRepository(
      apiClient: ApiClient(httpClient: fakeLoginBackend(validUsername: 'maria', validPassword: 'segredo123', operatorOnSuccess: _maria)),
    );
    await repository.login('maria', 'segredo123');

    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('sonho_de_crianca_session')!) as Map<String, dynamic>;
    expect(saved['token'], 'fake-token');
    expect((saved['operator'] as Map<String, dynamic>)['username'], 'maria');
    expect(saved.containsKey('password'), isFalse);
  });

  test('JWT com exp no passado não conta como logado (spec 027, cenário 3)', () {
    final now = DateTime(2026, 10, 2, 12);
    final repository = AuthRepository.withSession(
      token: _jwtExpiringAt(now.subtract(const Duration(minutes: 1))),
      operator: _maria,
      clock: () => now,
    );

    expect(repository.isLoggedIn, isFalse);
    expect(repository.token, isNull);
  });

  test('JWT ainda válido conta como logado', () {
    final now = DateTime(2026, 10, 2, 12);
    final token = _jwtExpiringAt(now.add(const Duration(hours: 11)));
    final repository = AuthRepository.withSession(token: token, operator: _maria, clock: () => now);

    expect(repository.isLoggedIn, isTrue);
    expect(repository.token, token);
  });

  test('restoreSession descarta sessão vencida do storage', () async {
    final now = DateTime(2026, 10, 2, 12);
    SharedPreferences.setMockInitialValues({
      'sonho_de_crianca_session': jsonEncode({
        'token': _jwtExpiringAt(now.subtract(const Duration(hours: 1))),
        'operator': _maria.toJson(),
      }),
    });

    final repository = AuthRepository(clock: () => now);
    await repository.restoreSession();

    expect(repository.isLoggedIn, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sonho_de_crianca_session'), isNull);
  });
}

/// JWT no formato do backend (header.payload.assinatura) — só o `exp` do
/// payload importa pro app; a assinatura nunca é checada localmente.
String _jwtExpiringAt(DateTime expiresAt) {
  String segment(Map<String, dynamic> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp = expiresAt.millisecondsSinceEpoch ~/ 1000;
  return '${segment({'alg': 'HS256', 'typ': 'JWT'})}.${segment({'operatorId': 'op1', 'name': 'Maria Souza', 'username': 'maria', 'iat': exp - 43200, 'exp': exp})}.assinatura';
}
