import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/operator.dart';
import '../services/api_client.dart';
import '../services/api_exceptions.dart';

/// Dono da sessão de operador (spec 024-sync-backend-fundacao) — instância
/// única (wired em `main.dart`), mesma convenção `ChangeNotifier` dos
/// outros Repositories. Guarda `{token, operator}` em armazenamento seguro
/// do aparelho (nunca `SharedPreferences` puro — é uma credencial de
/// sessão, não config) e é a fonte de verdade de `isLoggedIn`/`token` pros
/// outros Repositories montarem chamada autenticada.
///
/// `login`/`logout` deixam subir [ApiUnauthorizedException]/
/// [ApiNetworkException]/[ApiException] sem embrulhar — quem chama (o
/// `LoginCubit`) decide a mensagem certa por tipo, mesmo padrão que
/// [ApiClient] já usa.
class AuthRepository extends ChangeNotifier {
  AuthRepository({ApiClient? apiClient, FlutterSecureStorage? storage})
      : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? const FlutterSecureStorage();

  /// Sessão já pronta, sem tocar storage/rede — só pra teste de Repository
  /// que dependem de uma sessão (ex. `BusinessSettingsRepository`), sem
  /// precisar simular o `POST /api/auth/login` inteiro pra cada caso.
  @visibleForTesting
  AuthRepository.withSession({required String token, required Operator operator, ApiClient? apiClient, FlutterSecureStorage? storage})
      : _apiClient = apiClient ?? ApiClient(),
        _storage = storage ?? const FlutterSecureStorage() {
    _token = token;
    _currentOperator = operator;
  }

  static const _storageKey = 'sonho_de_crianca_session';

  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  Operator? _currentOperator;
  String? _token;
  String? _deviceToken;

  /// Mesma guarda que os outros Repositories usam pro próprio `load()`
  /// assíncrono no boot resolver depois deste já ter sido descartado.
  bool _disposed = false;

  Operator? get currentOperator => _currentOperator;
  String? get token => _token;
  bool get isLoggedIn => _token != null && _currentOperator != null;

  /// Sessão de dispositivo (spec 025-catalogo-sessao-dispositivo) — `null`
  /// até [loginDevice] resolver, ou se a credencial não estiver configurada
  /// nesta build. Separada da sessão de operador real acima: só serve pra
  /// leitura de catálogo, nunca pra ação que grava autoria/dinheiro.
  String? get deviceToken => _deviceToken;

  static const _deviceUsername = String.fromEnvironment('DEVICE_OPERATOR_USERNAME');
  static const _devicePassword = String.fromEnvironment('DEVICE_OPERATOR_PASSWORD');

  /// Lê a sessão salva, se houver — chamar uma vez no boot (`main.dart`),
  /// antes do `runApp`, mesmo padrão de `BusinessSettingsRepository.load()`.
  /// Sessão corrompida/formato antigo é descartada silenciosamente, nunca
  /// trava o boot do app.
  Future<void> restoreSession() async {
    final raw = await _storage.read(key: _storageKey);
    if (_disposed || raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _token = decoded['token'] as String;
      _currentOperator = Operator.fromJson(decoded['operator'] as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {
      await _storage.delete(key: _storageKey);
    }
  }

  /// `POST /api/auth/login`. Sucesso guarda a sessão (memória + storage) e
  /// notifica; falha deixa a exceção típada subir, sem tocar no estado
  /// atual (login errado não desloga quem já estava logado).
  Future<void> login(String username, String password) async {
    final response = await _apiClient.post('/api/auth/login', body: {'username': username, 'password': password});
    _token = response['token'] as String;
    _currentOperator = Operator.fromJson(response['operator'] as Map<String, dynamic>);
    await _persist();
    if (!_disposed) notifyListeners();
  }

  /// Login silencioso da sessão de dispositivo (spec 025) — chamar no boot
  /// e de novo sempre que uma chamada de catálogo voltar com 401 (token de
  /// 12h expirado). Credencial vem de constante de compilação
  /// (`--dart-define-from-file=secrets.json`, nunca commitada); vazia =
  /// build sem essa configuração, não tenta nada. Nunca lança — falha
  /// (sem rede, credencial errada, backend fora) só deixa [deviceToken]
  /// `null`; `ToyRepository.load()` já trata isso como cenário 4
  /// (mantém o catálogo em cache, sem avisar ninguém).
  Future<void> loginDevice() async {
    if (_deviceUsername.isEmpty || _devicePassword.isEmpty) return;
    try {
      final response = await _apiClient.post(
        '/api/auth/login',
        body: {'username': _deviceUsername, 'password': _devicePassword},
      );
      _deviceToken = response['token'] as String;
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Sem usuário pra avisar aqui — quem depende de deviceToken trata o
      // null como "sessão de dispositivo indisponível agora".
    }
  }

  /// Encerra a sessão local — chamado pelo operador (logout explícito) ou
  /// por qualquer Repository que receba 401 numa chamada autenticada
  /// (sessão expirada em uso, spec 024 cenário 5).
  Future<void> logout() async {
    _token = null;
    _currentOperator = null;
    await _storage.delete(key: _storageKey);
    if (!_disposed) notifyListeners();
  }

  Future<void> _persist() {
    return _storage.write(
      key: _storageKey,
      value: jsonEncode({'token': _token, 'operator': _currentOperator!.toJson()}),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
