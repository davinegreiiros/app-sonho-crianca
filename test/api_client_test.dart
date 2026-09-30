// Guarda de TLS do ApiClient (spec 024-sync-backend-fundacao + revisão do
// PR #4): `dart:io` não respeita o bloqueio de cleartext do Android/ATS do
// iOS, então o próprio client recusa base URL `http://` fora do debug.

import 'package:flutter_test/flutter_test.dart';

import 'package:sonho_de_crianca/data/services/api_client.dart';

void main() {
  test('recusa base URL http:// quando cleartext não é permitido (release/profile)', () {
    expect(
      () => ApiClient(baseUrl: 'http://192.168.0.10:3000', allowCleartext: false),
      throwsStateError,
    );
  });

  test('aceita https:// quando cleartext não é permitido', () {
    expect(() => ApiClient(baseUrl: 'https://sonho-de-crianca-backend.vercel.app', allowCleartext: false), returnsNormally);
  });

  test('aceita http:// em debug (next dev na rede local)', () {
    expect(() => ApiClient(baseUrl: 'http://192.168.0.10:3000', allowCleartext: true), returnsNormally);
  });
}
