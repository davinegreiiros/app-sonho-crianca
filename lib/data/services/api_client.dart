import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_exceptions.dart';

/// Wrapper fino sobre `package:http` — nenhum `Repository`/`Cubit` fala
/// HTTP direto (spec 024-sync-backend-fundacao). Resolve três coisas que
/// toda chamada ao backend precisa: base URL, timeout curto (nunca trava a
/// UI esperando o servidor indefinidamente — ligação com a revisão de
/// segurança/disponibilidade do backend), e erro tipado
/// ([ApiUnauthorizedException]/[ApiNetworkException]/[ApiException]) em vez
/// do erro cru do `http`/`dart:io`.
///
/// `httpClient` injetável pra teste (`package:http/testing.dart`,
/// `MockClient`) — nenhum teste desta fatia bate no backend real.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl, bool allowCleartext = kDebugMode})
      : _client = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? _defaultBaseUrl {
    // `dart:io` não respeita o bloqueio de cleartext do Android nem o ATS
    // do iOS — sem esta guarda, um release compilado com `API_BASE_URL`
    // em `http://` mandaria senha e Bearer token sem TLS. Falha no boot,
    // não na primeira requisição, pra o build errado nunca parecer ok.
    if (!allowCleartext && Uri.parse(_baseUrl).scheme != 'https') {
      throw StateError('API_BASE_URL precisa ser https fora do modo debug: $_baseUrl');
    }
  }

  /// Produção por padrão; aponta pra outro lugar (ex. `next dev` na rede
  /// local) via `flutter run --dart-define=API_BASE_URL=http://192.168.x.x:3000`
  /// — `http://` só é aceito em build debug (ver construtor).
  static const _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sonho-de-crianca-backend.vercel.app',
  );

  static const _timeout = Duration(seconds: 10);

  final http.Client _client;
  final String _baseUrl;

  Future<dynamic> get(String path, {String? token}) => _send('GET', path, token: token);
  Future<dynamic> post(String path, {Object? body, String? token}) => _send('POST', path, body: body, token: token);
  Future<dynamic> put(String path, {Object? body, String? token}) => _send('PUT', path, body: body, token: token);
  Future<dynamic> patch(String path, {Object? body, String? token}) => _send('PATCH', path, body: body, token: token);
  Future<dynamic> delete(String path, {String? token}) => _send('DELETE', path, token: token);

  Future<dynamic> _send(String method, String path, {Object? body, String? token}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final encodedBody = body == null ? null : jsonEncode(body);

    late final http.Response response;
    try {
      response = await _dispatch(method, uri, headers, encodedBody).timeout(_timeout);
    } on TimeoutException {
      throw const ApiNetworkException();
    } on SocketException {
      throw const ApiNetworkException();
    } on http.ClientException {
      throw const ApiNetworkException();
    }

    return _decode(response);
  }

  Future<http.Response> _dispatch(String method, Uri uri, Map<String, String> headers, String? body) {
    switch (method) {
      case 'GET':
        return _client.get(uri, headers: headers);
      case 'POST':
        return _client.post(uri, headers: headers, body: body);
      case 'PUT':
        return _client.put(uri, headers: headers, body: body);
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: body);
      case 'DELETE':
        return _client.delete(uri, headers: headers);
      default:
        throw UnsupportedError('Método HTTP não suportado: $method');
    }
  }

  dynamic _decode(http.Response response) {
    final status = response.statusCode;
    final isSuccess = status >= 200 && status < 300;

    Map<String, dynamic>? json;
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {
        // 204 sem corpo, ou corpo não-JSON — só importa se não for sucesso.
      }
    }

    if (isSuccess) return decoded;

    final message = json?['error'] as String? ?? 'Erro inesperado (status $status)';
    if (status == 401) throw ApiUnauthorizedException(message);
    throw ApiException(status, message);
  }
}
