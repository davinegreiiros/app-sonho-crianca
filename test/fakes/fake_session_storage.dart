// Zera o `SharedPreferences` em memória onde `AuthRepository` guarda a
// sessão do administrador (spec 027-login-admin-sessao, via
// `AuthSessionLocalService`) — sem isso uma sessão salva por um teste
// vazaria pro próximo. Chamar uma vez por teste (ex. em `setUp`).

import 'package:shared_preferences/shared_preferences.dart';

void setUpFakeSessionStorage() {
  SharedPreferences.setMockInitialValues({});
}
