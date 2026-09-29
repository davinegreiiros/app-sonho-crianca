// Tests for spec 011 (migração — configurações do negócio): the new
// Repository/Cubit are testable without a WidgetTester, and the two stay
// in sync when a Repository instance is shared (the exact bridge
// AppState relies on until end_rental_dialog.dart/pix_qr_sheet.dart
// migrate in fatia 014).

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/business_settings_repository.dart';
import 'package:sonho_de_crianca/domain/models/business_settings.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/ui/features/business_settings/view_models/business_settings_cubit.dart';
import 'package:sonho_de_crianca/ui/features/business_settings/view_models/business_settings_state.dart';

import 'fakes/fake_rental_notifier.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  group('BusinessSettingsRepository', () {
    test('starts with empty defaults and load() hydrates from persisted prefs', () async {
      SharedPreferences.setMockInitialValues({
        'business_merchant_name': 'Sonho de Criança',
        'business_merchant_city': 'Fortaleza',
        'business_pix_key': '85999998888',
      });
      final repository = BusinessSettingsRepository();
      expect(repository.settings, const BusinessSettings());

      await repository.load();

      expect(repository.settings.merchantName, 'Sonho de Criança');
      expect(repository.settings.merchantCity, 'Fortaleza');
      expect(repository.settings.pixKey, '85999998888');
    });

    test('update() sets in memory immediately and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = BusinessSettingsRepository();

      await repository.update(
        const BusinessSettings(merchantName: 'Loja X', merchantCity: 'Recife', pixKey: 'x@pix.com'),
      );

      expect(repository.settings.merchantName, 'Loja X');

      // A second repository reading the same (fake) SharedPreferences
      // proves update() actually persisted, not just held in memory.
      final reloaded = BusinessSettingsRepository();
      await reloaded.load();
      expect(reloaded.settings.merchantCity, 'Recife');
      expect(reloaded.settings.pixKey, 'x@pix.com');
    });
  });

  group('BusinessSettingsCubit', () {
    blocTest<BusinessSettingsCubit, BusinessSettingsState>(
      'save() persists through the Repository and emits the new state',
      setUp: () => SharedPreferences.setMockInitialValues({}),
      build: () => BusinessSettingsCubit(BusinessSettingsRepository()),
      act: (cubit) => cubit.save(merchantName: 'Sonho de Criança', merchantCity: 'Fortaleza', pixKey: '85999998888'),
      expect: () => [
        const BusinessSettingsState(
          settings: BusinessSettings(merchantName: 'Sonho de Criança', merchantCity: 'Fortaleza', pixKey: '85999998888'),
        ),
      ],
    );

    test('shares state with AppState.businessSettings when the same Repository instance is injected', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = BusinessSettingsRepository();
      final cubit = BusinessSettingsCubit(repository);
      final state = AppState(notifications: FakeRentalNotifier(), businessSettingsRepository: repository);

      await cubit.save(merchantName: 'Sonho de Criança', merchantCity: 'Fortaleza', pixKey: '85999998888');

      // Same Repository instance -> AppState (old world) sees exactly what
      // the new Cubit just saved, with no separate/divergent copy.
      expect(state.businessSettings.merchantName, 'Sonho de Criança');
      expect(state.businessSettings, cubit.state.settings);

      await cubit.close();
      state.dispose();
    });
  });
}
