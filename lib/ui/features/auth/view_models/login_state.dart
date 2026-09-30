import 'package:equatable/equatable.dart';

/// Estado emitido por [LoginCubit] (spec 024-sync-backend-fundacao).
/// `credenciaisInvalidas`/`semConexao`/`erro` são distintos de propósito —
/// [LoginView] mostra mensagem diferente pra cada (cenários 3 e 6 do spec:
/// "usuário ou senha errados" não é a mesma coisa que "sem conexão").
enum LoginStatus { idle, loading, credenciaisInvalidas, semConexao, erro, sucesso }

class LoginState extends Equatable {
  const LoginState({this.status = LoginStatus.idle, this.errorMessage});

  final LoginStatus status;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, errorMessage];
}
