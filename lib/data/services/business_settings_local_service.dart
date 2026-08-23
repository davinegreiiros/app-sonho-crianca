import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/business_settings.dart';

/// Stateless wrapper around `SharedPreferences` for `BusinessSettings`
/// (spec 011-migracao-configuracoes-negocio). Never called directly by a
/// `Cubit`/`View` — only `BusinessSettingsRepository` talks to this.
class BusinessSettingsLocalService {
  const BusinessSettingsLocalService();

  static const _prefsMerchantName = 'business_merchant_name';
  static const _prefsMerchantCity = 'business_merchant_city';
  static const _prefsPixKey = 'business_pix_key';

  Future<BusinessSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return BusinessSettings(
      merchantName: prefs.getString(_prefsMerchantName) ?? '',
      merchantCity: prefs.getString(_prefsMerchantCity) ?? '',
      pixKey: prefs.getString(_prefsPixKey) ?? '',
    );
  }

  Future<void> save(BusinessSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsMerchantName, settings.merchantName);
    await prefs.setString(_prefsMerchantCity, settings.merchantCity);
    await prefs.setString(_prefsPixKey, settings.pixKey);
  }
}
