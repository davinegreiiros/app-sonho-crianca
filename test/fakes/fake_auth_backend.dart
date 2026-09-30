// Fake do `POST /api/auth/login` (spec 024-sync-backend-fundacao) — nenhum
// teste desta fatia bate no backend real.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sonho_de_crianca/domain/models/operator.dart';

/// 200 + `{token, operator}` pra `validUsername`/`validPassword`; 401 com
/// mensagem de negócio pra qualquer outra combinação — mesmo contrato do
/// backend real (`specs/001-fundacao-auth-crud` no repo
/// `sonho-de-crianca-backend`).
http.Client fakeLoginBackend({
  required String validUsername,
  required String validPassword,
  required Operator operatorOnSuccess,
  String token = 'fake-token',
}) {
  return MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (body['username'] == validUsername && body['password'] == validPassword) {
      return http.Response(jsonEncode({'token': token, 'operator': operatorOnSuccess.toJson()}), 200);
    }
    return http.Response(jsonEncode({'error': 'Usuário ou senha inválidos'}), 401);
  });
}

/// Simula sem conexão — qualquer chamada lança, `ApiClient` mapeia pra
/// `ApiNetworkException` (spec 024, cenário 6).
http.Client fakeUnreachableBackend() {
  return MockClient((request) async {
    throw http.ClientException('sem rede (fake)');
  });
}
