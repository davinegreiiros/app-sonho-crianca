import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/business_settings_repository.dart';
import '../../../../domain/models/business_settings.dart';
import 'business_settings_state.dart';

/// ViewModel for [BusinessSettingsView] (spec
/// 011-migracao-configuracoes-negocio; sincronização com backend na
/// 024-sync-backend-fundacao) — reads/writes through the shared
/// [BusinessSettingsRepository], never touches HTTP/`ApiClient` itself.
class BusinessSettingsCubit extends Cubit<BusinessSettingsState> {
  BusinessSettingsCubit(this._repository)
      : super(BusinessSettingsState(settings: _repository.settings, status: _repository.status)) {
    _repository.addListener(_onRepositoryChanged);
  }

  final BusinessSettingsRepository _repository;

  void _onRepositoryChanged() => emit(BusinessSettingsState(settings: _repository.settings, status: _repository.status));

  /// Busca o valor atual no backend — chamado pela `View` ao entrar na tela
  /// (spec 024: não carrega no boot do app, só quando a tela abre de fato,
  /// pra não atrasar o boot com uma chamada de rede que ninguém pediu ainda).
  Future<void> refresh() => _repository.load();

  Future<void> save({required String merchantName, required String merchantCity, required String pixKey}) {
    return _repository.update(BusinessSettings(merchantName: merchantName, merchantCity: merchantCity, pixKey: pixKey));
  }

  @override
  Future<void> close() {
    _repository.removeListener(_onRepositoryChanged);
    return super.close();
  }
}
