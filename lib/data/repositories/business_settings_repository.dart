import 'package:flutter/foundation.dart';

import '../../domain/models/business_settings.dart';
import '../services/api_exceptions.dart';
import '../services/business_settings_remote_service.dart';
import 'auth_repository.dart';

/// Estado da última tentativa de sincronizar com o backend — sinal a mais
/// que [BusinessSettingsRepository] notifica junto do `settings` (spec
/// 024-sync-backend-fundacao). Consumidores antigos (`AppState` proxy,
/// telas ainda não migradas) ignoram isto e continuam lendo só `settings`,
/// que nunca lança e sempre devolve o último valor conhecido.
enum BusinessSettingsSyncStatus { idle, loading, loaded, unauthorized, networkError }

/// Single source of truth for `BusinessSettings` (spec
/// 011-migracao-configuracoes-negocio; a partir da 024, sincronizado com o
/// backend em vez de `SharedPreferences`) — one shared instance (wired in
/// `main.dart`) consumed both by `BusinessSettingsCubit` (new world,
/// `lib/ui/features/business_settings/`) and by `AppState.businessSettings`
/// (old world, kept as a thin proxy until `end_rental_dialog.dart`/
/// `pix_qr_sheet.dart` migrate). Never construct two of these in the same
/// running app — that would split the source of truth.
///
/// Troca de arquitetura na 024: o Service por baixo virou HTTP
/// ([BusinessSettingsRemoteService]), não mais `SharedPreferences` — a
/// interface pública (`settings`, `load()`, `update()`, `ChangeNotifier`)
/// não mudou, só ganhou [status]. 401 em qualquer chamada desloga via
/// `AuthRepository.logout` — quem decide navegar pro login é a `View`,
/// lendo [status].
class BusinessSettingsRepository extends ChangeNotifier {
  BusinessSettingsRepository({
    required BusinessSettingsRemoteService service,
    required AuthRepository authRepository,
  })  : _service = service,
        _authRepository = authRepository;

  final BusinessSettingsRemoteService _service;
  final AuthRepository _authRepository;

  BusinessSettings _settings = const BusinessSettings();
  BusinessSettings get settings => _settings;

  BusinessSettingsSyncStatus _status = BusinessSettingsSyncStatus.idle;
  BusinessSettingsSyncStatus get status => _status;

  /// Set by [dispose] — mirrors the guard `AppState` already used for its
  /// own async-at-boot load, needed for the same reason: [load]'s `await`
  /// can resolve after this repository is gone.
  bool _disposed = false;

  /// Busca as configurações no backend. Começa no default (`const
  /// BusinessSettings()`) e mantém o último valor conhecido em caso de
  /// erro — `settings` nunca lança; [status] carrega o motivo do erro pra
  /// quem quiser reagir (spec 024, cenários 5/6).
  Future<void> load() async {
    _status = BusinessSettingsSyncStatus.loading;
    notifyListeners();
    try {
      final loaded = await _service.load(token: _authRepository.token);
      if (_disposed) return;
      _settings = loaded;
      _status = BusinessSettingsSyncStatus.loaded;
    } on ApiUnauthorizedException {
      await _authRepository.logout();
      _status = BusinessSettingsSyncStatus.unauthorized;
    } on ApiNetworkException {
      _status = BusinessSettingsSyncStatus.networkError;
    }
    if (!_disposed) notifyListeners();
  }

  /// Atualiza em memória e notifica imediatamente (otimista — mesma ordem
  /// que `AppState.updateBusinessSettings` já usava), depois persiste no
  /// backend. Se a escrita falhar, o valor em memória já mudou (mesma
  /// escolha de design de antes) — [status] carrega o motivo pra `View`
  /// avisar, mas não desfaz o valor local.
  Future<void> update(BusinessSettings settings) async {
    _settings = settings;
    notifyListeners();
    if (_disposed) return;
    try {
      await _service.save(settings, token: _authRepository.token);
      _status = BusinessSettingsSyncStatus.loaded;
    } on ApiUnauthorizedException {
      await _authRepository.logout();
      _status = BusinessSettingsSyncStatus.unauthorized;
    } on ApiNetworkException {
      _status = BusinessSettingsSyncStatus.networkError;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
