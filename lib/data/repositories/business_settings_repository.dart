import 'package:flutter/foundation.dart';

import '../../domain/models/business_settings.dart';
import '../services/business_settings_local_service.dart';

/// Single source of truth for `BusinessSettings` (spec
/// 011-migracao-configuracoes-negocio) — one shared instance (wired in
/// `main.dart`) consumed both by `BusinessSettingsCubit` (new world,
/// `lib/ui/features/business_settings/`) and by `AppState.businessSettings`
/// (old world, kept as a thin proxy until `end_rental_dialog.dart`/
/// `pix_qr_sheet.dart` migrate in fatia 017+). Never construct two of these
/// in the same running app — that would split the source of truth.
class BusinessSettingsRepository extends ChangeNotifier {
  BusinessSettingsRepository({BusinessSettingsLocalService? service})
      : _service = service ?? const BusinessSettingsLocalService();

  final BusinessSettingsLocalService _service;

  BusinessSettings _settings = const BusinessSettings();
  BusinessSettings get settings => _settings;

  /// Set by [dispose] — mirrors the guard `AppState` already used for its
  /// own async-at-boot load, needed for the same reason: [load]'s `await`
  /// can resolve after this repository is gone.
  bool _disposed = false;

  /// Loads the persisted settings, if any, from local device storage.
  /// Starts with the `const BusinessSettings()` default and notifies once
  /// this resolves — safe to call more than once (idempotent re-read).
  Future<void> load() async {
    final loaded = await _service.load();
    if (_disposed) return;
    _settings = loaded;
    notifyListeners();
  }

  /// Updates in memory and notifies immediately (optimistic — same order
  /// the old `AppState.updateBusinessSettings` used), then persists.
  Future<void> update(BusinessSettings settings) async {
    _settings = settings;
    notifyListeners();
    if (_disposed) return;
    await _service.save(settings);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
