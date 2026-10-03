import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper stateless de `SharedPreferences` pra sessão do administrador
/// (spec 027-login-admin-sessao — substitui `flutter_secure_storage`, ver
/// "Trade-off aceito" no `spec.md`). Guarda o JSON cru `{token, operator}`;
/// quem interpreta é o `AuthRepository`, nunca um `Cubit`/`View`.
class AuthSessionLocalService {
  const AuthSessionLocalService();

  static const _key = 'sonho_de_crianca_session';

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> write(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
  }

  Future<void> delete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
