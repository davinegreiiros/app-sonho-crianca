import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/models/operator.dart';
import '../services/api_client.dart';
import '../services/api_exceptions.dart';
import '../services/auth_session_local_service.dart';

/// Dono da sessão do administrador (spec 024-sync-backend-fundacao,
/// revisada na 027-login-admin-sessao) — instância única (wired em
/// `main.dart`), mesma convenção `ChangeNotifier` dos outros Repositories.
///
/// Uma sessão só (027): o mesmo token do administrador serve pra leitura e
/// escrita — não existe mais "sessão de dispositivo" (backend#002: login é
/// único, do administrador). Persistida em `SharedPreferences`
/// ([AuthSessionLocalService]) pra o posto continuar registrando locação
/// depois que o administrador volta pros postos, até o JWT expirar (12h,
/// sem refresh — backend#001).
///
/// `login`/`logout` deixam subir [ApiUnauthorizedException]/
/// [ApiNetworkException]/[ApiException] sem embrulhar — quem chama (o
/// `LoginCubit`) decide a mensagem certa por tipo, mesmo padrão que
/// [ApiClient] já usa.
class AuthRepository extends ChangeNotifier {
  AuthRepository({ApiClient? apiClient, AuthSessionLocalService? localService, DateTime Function()? clock})
      : _apiClient = apiClient ?? ApiClient(),
        _localService = localService ?? const AuthSessionLocalService(),
        _clock = clock ?? DateTime.now;

  /// Sessão já pronta, sem tocar storage/rede — só pra teste de Repository
  /// que dependem de uma sessão (ex. `BusinessSettingsRepository`), sem
  /// precisar simular o `POST /api/auth/login` inteiro pra cada caso.
  @visibleForTesting
  AuthRepository.withSession({
    required String token,
    required Operator operator,
    ApiClient? apiClient,
    AuthSessionLocalService? localService,
    DateTime Function()? clock,
  })  : _apiClient = apiClient ?? ApiClient(),
        _localService = localService ?? const AuthSessionLocalService(),
        _clock = clock ?? DateTime.now {
    _token = token;
    _currentOperator = operator;
  }

  final ApiClient _apiClient;
  final AuthSessionLocalService _localService;
  final DateTime Function() _clock;

  Operator? _currentOperator;
  String? _token;

  /// Mesma guarda que os outros Repositories usam pro próprio `load()`
  /// assíncrono no boot resolver depois deste já ter sido descartado.
  bool _disposed = false;

  Operator? get currentOperator => isLoggedIn ? _currentOperator : null;

  /// `null` se não há sessão ou se o JWT já expirou — quem monta chamada
  /// autenticada nunca manda token que o backend vai recusar.
  String? get token => isLoggedIn ? _token : null;

  bool get isLoggedIn {
    final token = _token;
    if (token == null || _currentOperator == null) return false;
    final expiresAt = _expiresAt(token);
    return expiresAt == null || _clock().isBefore(expiresAt);
  }

  /// Lê a sessão salva, se houver — chamar uma vez no boot (`main.dart`),
  /// antes do `runApp`. Sessão expirada, corrompida ou de formato antigo é
  /// descartada silenciosamente, nunca trava o boot do app.
  Future<void> restoreSession() async {
    final raw = await _localService.read();
    if (_disposed || raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _token = decoded['token'] as String;
      _currentOperator = Operator.fromJson(decoded['operator'] as Map<String, dynamic>);
    } catch (_) {
      _token = null;
      _currentOperator = null;
    }
    if (!isLoggedIn) {
      _token = null;
      _currentOperator = null;
      await _localService.delete();
      return;
    }
    notifyListeners();
  }

  /// `POST /api/auth/login`. Sucesso guarda a sessão (memória + storage) e
  /// notifica; falha deixa a exceção típada subir, sem tocar no estado
  /// atual (login errado não desloga quem já estava logado).
  Future<void> login(String username, String password) async {
    final response = await _apiClient.post('/api/auth/login', body: {'username': username, 'password': password});
    _token = response['token'] as String;
    _currentOperator = Operator.fromJson(response['operator'] as Map<String, dynamic>);
    await _localService.write(jsonEncode({'token': _token, 'operator': _currentOperator!.toJson()}));
    if (!_disposed) notifyListeners();
  }

  /// Encerra a sessão local — chamado pelo administrador ("Sair da conta",
  /// spec 027) ou por qualquer Repository que receba 401 numa chamada
  /// autenticada (sessão expirada em uso, spec 024 cenário 5).
  Future<void> logout() async {
    _token = null;
    _currentOperator = null;
    await _localService.delete();
    if (!_disposed) notifyListeners();
  }

  /// `exp` do payload do JWT (sem verificar assinatura — isso é papel do
  /// backend; aqui só evita tratar como válido um token sabidamente
  /// vencido). Token sem `exp` legível = validade desconhecida, quem
  /// decide é o backend (401 derruba a sessão do mesmo jeito).
  static DateTime? _expiresAt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload is Map<String, dynamic> ? payload['exp'] : null;
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch((exp * 1000).round());
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
