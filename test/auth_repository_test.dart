// Tests for spec 024-sync-backend-fundacao — AuthRepository: login
// ok/errado, sessão persiste e sobrevive "restart" (nova instância lendo o
// mesmo storage), logout limpa, erro de rede é distinto de credencial.

import 'package:flutter_test/flutter_test.dart';

import 'package:sonho_de_crianca/data/repositories/auth_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/data/services/api_exceptions.dart';
import 'package:sonho_de_crianca/domain/models/operator.dart';

import 'fakes/fake_auth_backend.dart';
import 'fakes/fake_secure_storage.dart';

const _maria = Operator(id: 'op1', name: 'Maria Souza', username: 'maria');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setUpFakeSecureStorage);

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
}
