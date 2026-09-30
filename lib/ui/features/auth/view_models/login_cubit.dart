import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/api_exceptions.dart';
import 'login_state.dart';

/// ViewModel for [LoginView] (spec 024-sync-backend-fundacao) — só chama
/// [AuthRepository.login], nunca fala com [ApiClient]/HTTP direto.
class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._authRepository) : super(const LoginState());

  final AuthRepository _authRepository;

  Future<void> submit(String username, String password) async {
    if (username.trim().isEmpty || password.isEmpty) {
      emit(const LoginState(status: LoginStatus.credenciaisInvalidas, errorMessage: 'Informe usuário e senha'));
      return;
    }

    emit(const LoginState(status: LoginStatus.loading));
    try {
      await _authRepository.login(username.trim(), password);
      emit(const LoginState(status: LoginStatus.sucesso));
    } on ApiUnauthorizedException catch (e) {
      emit(LoginState(status: LoginStatus.credenciaisInvalidas, errorMessage: e.message));
    } on ApiNetworkException catch (e) {
      emit(LoginState(status: LoginStatus.semConexao, errorMessage: e.message));
    } on ApiException catch (e) {
      emit(LoginState(status: LoginStatus.erro, errorMessage: e.message));
    }
  }
}
