// Mocka o MethodChannel do `flutter_secure_storage`
// (`plugins.it_nomads.com/flutter_secure_storage`) com um mapa em memória —
// sem plugin de plataforma real disponível no ambiente de teste, a chamada
// de `AuthRepository` (spec 024-sync-backend-fundacao) lançaria
// `MissingPluginException`. Chamar uma vez por teste (ex. em `setUp`);
// `TestWidgetsFlutterBinding.ensureInitialized()` precisa já ter rodado.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void setUpFakeSecureStorage() {
  final store = <String, String>{};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    switch (call.method) {
      case 'read':
        return store[args['key'] as String];
      case 'write':
        store[args['key'] as String] = args['value'] as String;
        return null;
      case 'delete':
        store.remove(args['key'] as String);
        return null;
      case 'deleteAll':
        store.clear();
        return null;
      case 'containsKey':
        return store.containsKey(args['key'] as String);
      case 'readAll':
        return store;
      default:
        return null;
    }
  });
}
