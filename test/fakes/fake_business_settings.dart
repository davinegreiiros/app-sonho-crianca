// Fakes compartilhados pra testes que passam por telas que exigem sessão
// de operador (spec 024-sync-backend-fundacao) sem bater no backend real
// — hoje só `BusinessSettingsView`/Configurações.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sonho_de_crianca/data/repositories/auth_repository.dart';
import 'package:sonho_de_crianca/data/repositories/business_settings_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/data/services/business_settings_remote_service.dart';
import 'package:sonho_de_crianca/domain/models/business_settings.dart';
import 'package:sonho_de_crianca/domain/models/operator.dart';

const fakeTestOperator = Operator(id: 'op1', name: 'Operador Teste', username: 'teste');

/// Sessão já autenticada, sem tocar storage/rede — testes que precisam
/// passar pela guarda de login em `openBusinessSettingsScreen` sem
/// exercitar a `LoginView` em si usam isto.
AuthRepository fakeLoggedInAuthRepository() => AuthRepository.withSession(token: 'fake-token', operator: fakeTestOperator);

/// Backend fake em memória: `GET` devolve o último valor salvo (começa em
/// [initial]), `PUT` substitui. Repositórios diferentes que compartilham o
/// mesmo [http.Client] (`MockClient`) enxergam o mesmo "servidor" — usar
/// pra testar sync entre "duas instâncias"/"dois aparelhos".
http.Client fakeBusinessSettingsBackend({BusinessSettings initial = const BusinessSettings()}) {
  var current = initial;
  return MockClient((request) async {
    if (request.method == 'GET') {
      return http.Response(
        jsonEncode({'merchantName': current.merchantName, 'merchantCity': current.merchantCity, 'pixKey': current.pixKey}),
        200,
      );
    }
    if (request.method == 'PUT') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      current = BusinessSettings(
        merchantName: body['merchantName'] as String,
        merchantCity: body['merchantCity'] as String,
        pixKey: body['pixKey'] as String,
      );
      return http.Response(jsonEncode(body), 200);
    }
    return http.Response(jsonEncode({'error': 'não suportado neste fake'}), 404);
  });
}

BusinessSettingsRepository fakeBusinessSettingsRepository({
  BusinessSettings initial = const BusinessSettings(),
  AuthRepository? authRepository,
}) =>
    BusinessSettingsRepository(
      service: BusinessSettingsRemoteService(ApiClient(httpClient: fakeBusinessSettingsBackend(initial: initial))),
      authRepository: authRepository ?? fakeLoggedInAuthRepository(),
    );
