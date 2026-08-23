import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/business_settings_repository.dart';
import '../../../../domain/models/business_settings.dart';
import 'business_settings_state.dart';

/// ViewModel for [BusinessSettingsView] (spec
/// 011-migracao-configuracoes-negocio) — reads/writes through the shared
/// [BusinessSettingsRepository], never touches `SharedPreferences` itself.
class BusinessSettingsCubit extends Cubit<BusinessSettingsState> {
  BusinessSettingsCubit(this._repository) : super(BusinessSettingsState(settings: _repository.settings)) {
    _repository.addListener(_onRepositoryChanged);
  }

  final BusinessSettingsRepository _repository;

  void _onRepositoryChanged() => emit(BusinessSettingsState(settings: _repository.settings));

  Future<void> save({required String merchantName, required String merchantCity, required String pixKey}) {
    return _repository.update(BusinessSettings(merchantName: merchantName, merchantCity: merchantCity, pixKey: pixKey));
  }

  @override
  Future<void> close() {
    _repository.removeListener(_onRepositoryChanged);
    return super.close();
  }
}
