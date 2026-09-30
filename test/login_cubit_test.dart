// Tests for spec 024-sync-backend-fundacao — LoginCubit: mensagem certa
// por tipo de erro (credencial vs. rede), nunca genérica.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonho_de_crianca/data/repositories/auth_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/domain/models/operator.dart';
import 'package:sonho_de_crianca/ui/features/auth/view_models/login_cubit.dart';
import 'package:sonho_de_crianca/ui/features/auth/view_models/login_state.dart';

import 'fakes/fake_auth_backend.dart';
import 'fakes/fake_secure_storage.dart';

const _maria = Operator(id: 'op1', name: 'Maria Souza', username: 'maria');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(setUpFakeSecureStorage);

  blocTest<LoginCubit, LoginState>(
    'campos vazios: erro de credencial sem chamar o backend',
    build: () => LoginCubit(AuthRepository(apiClient: ApiClient(httpClient: fakeUnreachableBackend()))),
    act: (cubit) => cubit.submit('', ''),
    expect: () => [const LoginState(status: LoginStatus.credenciaisInvalidas, errorMessage: 'Informe usuário e senha')],
  );

  blocTest<LoginCubit, LoginState>(
    'credenciais corretas: loading -> sucesso',
    build: () => LoginCubit(
      AuthRepository(apiClient: ApiClient(httpClient: fakeLoginBackend(validUsername: 'maria', validPassword: 'segredo123', operatorOnSuccess: _maria))),
    ),
    act: (cubit) => cubit.submit('maria', 'segredo123'),
    expect: () => [const LoginState(status: LoginStatus.loading), const LoginState(status: LoginStatus.sucesso)],
  );

  blocTest<LoginCubit, LoginState>(
    'senha errada: loading -> credenciaisInvalidas com mensagem do backend',
    build: () => LoginCubit(
      AuthRepository(apiClient: ApiClient(httpClient: fakeLoginBackend(validUsername: 'maria', validPassword: 'segredo123', operatorOnSuccess: _maria))),
    ),
    act: (cubit) => cubit.submit('maria', 'errada'),
    expect: () => [
      const LoginState(status: LoginStatus.loading),
      const LoginState(status: LoginStatus.credenciaisInvalidas, errorMessage: 'Usuário ou senha inválidos'),
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'sem conexão: loading -> semConexao, mensagem distinta de credencial errada',
    build: () => LoginCubit(AuthRepository(apiClient: ApiClient(httpClient: fakeUnreachableBackend()))),
    act: (cubit) => cubit.submit('maria', 'segredo123'),
    expect: () => [
      const LoginState(status: LoginStatus.loading),
      const LoginState(status: LoginStatus.semConexao, errorMessage: 'Sem conexão com o servidor'),
    ],
  );
}
