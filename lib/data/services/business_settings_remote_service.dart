import '../../domain/models/business_settings.dart';
import 'api_client.dart';

/// Sucessor de `BusinessSettingsLocalService` (spec
/// 024-sync-backend-fundacao) — mesma forma (`load()`/`save()`), por baixo
/// chama o backend em vez de `SharedPreferences`. `token` vem de
/// `AuthRepository` a cada chamada (não guardado aqui — este Service é
/// stateless, mesma regra da constitution pra `lib/data/services/`).
/// `ApiUnauthorizedException`/`ApiNetworkException` sobem sem tratamento —
/// quem decide o que fazer é `BusinessSettingsRepository`.
class BusinessSettingsRemoteService {
  const BusinessSettingsRemoteService(this._apiClient);

  final ApiClient _apiClient;

  Future<BusinessSettings> load({required String? token}) async {
    final json = await _apiClient.get('/api/business-settings', token: token) as Map<String, dynamic>;
    return BusinessSettings(
      merchantName: json['merchantName'] as String? ?? '',
      merchantCity: json['merchantCity'] as String? ?? '',
      pixKey: json['pixKey'] as String? ?? '',
    );
  }

  Future<void> save(BusinessSettings settings, {required String? token}) {
    return _apiClient.put(
      '/api/business-settings',
      token: token,
      body: {
        'merchantName': settings.merchantName,
        'merchantCity': settings.merchantCity,
        'pixKey': settings.pixKey,
      },
    );
  }
}
