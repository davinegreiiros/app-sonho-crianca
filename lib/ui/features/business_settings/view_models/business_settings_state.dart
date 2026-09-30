import 'package:equatable/equatable.dart';

import '../../../../data/repositories/business_settings_repository.dart';
import '../../../../domain/models/business_settings.dart';

/// State emitted by [BusinessSettingsCubit] — a thin envelope around the
/// domain model. Not to be confused with [BusinessSettings] itself: this
/// is what the `Cubit` emits, that's the actual data.
///
/// `status` (spec 024-sync-backend-fundacao) espelha
/// [BusinessSettingsSyncStatus] do Repository — a `View` usa pra saber se
/// deve mostrar loading, voltar pro login (`unauthorized`) ou avisar sem
/// conexão (`networkError`) / erro do servidor (`serverError`), sem precisar
/// de um estado próprio pra isso.
class BusinessSettingsState extends Equatable {
  const BusinessSettingsState({required this.settings, this.status = BusinessSettingsSyncStatus.idle});

  final BusinessSettings settings;
  final BusinessSettingsSyncStatus status;

  @override
  List<Object?> get props => [settings.merchantName, settings.merchantCity, settings.pixKey, status];
}
