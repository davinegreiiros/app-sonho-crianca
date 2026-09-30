/// Erros que [ApiClient] lança — todo `Cubit` que fala com o backend
/// (spec 024-sync-backend-fundacao) trata estes três tipos, nunca o erro
/// cru do `package:http`/`dart:io`, pra poder mostrar mensagem específica
/// (credencial vs. sessão vs. rede) em vez de um genérico.
library;

/// Requisição sem `Authorization`, com token inválido, ou 401 do backend
/// (token expirado). Quem recebe isto deve encerrar a sessão local e voltar
/// pro login — nunca mostrar como erro genérico.
class ApiUnauthorizedException implements Exception {
  const ApiUnauthorizedException([this.message = 'Sessão expirada']);
  final String message;

  @override
  String toString() => message;
}

/// Sem conexão, timeout, ou o backend não respondeu a tempo — distinto de
/// erro de credencial/validação (spec 024, cenário 6: aviso específico de
/// conectividade).
class ApiNetworkException implements Exception {
  const ApiNetworkException([this.message = 'Sem conexão com o servidor']);
  final String message;

  @override
  String toString() => message;
}

/// Qualquer outra resposta não-2xx do backend (400/404/409/500) — mensagem
/// já é a de negócio que o backend devolveu (`errorResponse` do repo
/// `sonho-de-crianca-backend`), segura pra mostrar direto na UI.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}
