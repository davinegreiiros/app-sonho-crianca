import 'package:equatable/equatable.dart';

import '../../../../domain/models/business_settings.dart';

/// State emitted by [BusinessSettingsCubit] — a thin envelope around the
/// domain model. Not to be confused with [BusinessSettings] itself: this
/// is what the `Cubit` emits, that's the actual data.
class BusinessSettingsState extends Equatable {
  const BusinessSettingsState({required this.settings});

  final BusinessSettings settings;

  @override
  List<Object?> get props => [settings.merchantName, settings.merchantCity, settings.pixKey];
}
