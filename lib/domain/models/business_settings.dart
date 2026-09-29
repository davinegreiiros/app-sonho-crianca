/// Business-level config for generating Pix charges: who's receiving the
/// money, not who's renting the toy. Kept separate from `Toy`/`Rental` —
/// this doesn't change per locação, it's set once by the operator.
///
/// Persisted locally via `shared_preferences` (see `AppState`) — never
/// hardcoded in source, never committed (spec 002-seguranca-dados).
class BusinessSettings {
  const BusinessSettings({
    this.merchantName = '',
    this.merchantCity = '',
    this.pixKey = '',
  });

  final String merchantName;
  final String merchantCity;
  final String pixKey;

  bool get isConfigured => merchantName.trim().isNotEmpty && merchantCity.trim().isNotEmpty && pixKey.trim().isNotEmpty;

  BusinessSettings copyWith({String? merchantName, String? merchantCity, String? pixKey}) => BusinessSettings(
        merchantName: merchantName ?? this.merchantName,
        merchantCity: merchantCity ?? this.merchantCity,
        pixKey: pixKey ?? this.pixKey,
      );
}
