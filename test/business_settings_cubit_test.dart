// Tests for spec 011 (migração — configurações do negócio) +
// 024-sync-backend-fundacao (troca de SharedPreferences por HTTP): o
// Repository/Cubit continuam testáveis sem WidgetTester, e os dois seguem
// em sincronia quando uma instância de Repository é compartilhada (a
// mesma ponte que AppState usa até end_rental_dialog.dart/pix_qr_sheet.dart
// migrarem). `ApiClient` roda contra um `MockClient` — nenhum teste bate
// no backend real.

import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sonho_de_crianca/data/repositories/auth_repository.dart';
import 'package:sonho_de_crianca/data/repositories/business_settings_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/data/services/business_settings_remote_service.dart';
import 'package:sonho_de_crianca/domain/models/business_settings.dart';
import 'package:sonho_de_crianca/domain/models/operator.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/ui/features/business_settings/view_models/business_settings_cubit.dart';
import 'package:sonho_de_crianca/ui/features/business_settings/view_models/business_settings_state.dart';

import 'fakes/fake_rental_notifier.dart';
import 'fakes/fake_secure_storage.dart';

const _testOperator = Operator(id: 'op1', name: 'Maria', username: 'maria');

/// Simula o backend em memória: `GET` devolve o último `BusinessSettings`
/// salvo (começa em [initial]), `PUT` substitui e devolve o novo valor.
/// Usar o mesmo [http.Client] em duas instâncias de Repository simula
/// "dois aparelhos" lendo/escrevendo o mesmo servidor.
http.Client _fakeBackend({BusinessSettings initial = const BusinessSettings()}) {
  var current = initial;
  return MockClient((request) async {
    if (request.method == 'GET') {
      return http.Response(
        jsonEncode({'merchantName': current.merchantName, 'merchantCity': current.merchantCity, 'pixKey': current.pixKey}),
        200,
      );
    }
    if (request.method == 'PUT') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      current = BusinessSettings(
        merchantName: body['merchantName'] as String,
        merchantCity: body['merchantCity'] as String,
        pixKey: body['pixKey'] as String,
      );
      return http.Response(jsonEncode(body), 200);
    }
    return http.Response(jsonEncode({'error': 'não suportado neste fake'}), 404);
  });
}

BusinessSettingsRepository _repository(http.Client client, {AuthRepository? authRepository}) => BusinessSettingsRepository(
      service: BusinessSettingsRemoteService(ApiClient(httpClient: client)),
      authRepository: authRepository ?? AuthRepository.withSession(token: 'fake-token', operator: _testOperator),
    );

/// Devolve 401 em qualquer chamada — simula token expirado em uso (spec
/// 024, cenário 5).
http.Client _fakeExpiredSessionBackend() =>
    MockClient((request) async => http.Response(jsonEncode({'error': 'Token inválido ou expirado'}), 401));

/// Lança em qualquer chamada — simula sem conexão (spec 024, cenário 6).
http.Client _fakeUnreachableBackend() => MockClient((request) async => throw http.ClientException('sem rede (fake)'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(setUpFakeSecureStorage);

  group('BusinessSettingsRepository', () {
    test('starts with empty defaults and load() hydrates from the backend', () async {
      final repository = _repository(_fakeBackend(
        initial: const BusinessSettings(merchantName: 'Sonho de Criança', merchantCity: 'Fortaleza', pixKey: '85999998888'),
      ));
      expect(repository.settings, const BusinessSettings());

      await repository.load();

      expect(repository.settings.merchantName, 'Sonho de Criança');
      expect(repository.settings.merchantCity, 'Fortaleza');
      expect(repository.settings.pixKey, '85999998888');
      expect(repository.status, BusinessSettingsSyncStatus.loaded);
    });

    test('update() sets in memory immediately and persists no backend', () async {
      final client = _fakeBackend();
      final repository = _repository(client);

      await repository.update(
        const BusinessSettings(merchantName: 'Loja X', merchantCity: 'Recife', pixKey: 'x@pix.com'),
      );

      expect(repository.settings.merchantName, 'Loja X');
      expect(repository.status, BusinessSettingsSyncStatus.loaded);

      // A second repository reading o mesmo fake backend prova que
      // update() persistiu de verdade, não só em memória.
      final reloaded = _repository(client);
      await reloaded.load();
      expect(reloaded.settings.merchantCity, 'Recife');
      expect(reloaded.settings.pixKey, 'x@pix.com');
    });

    test('401 (sessão expirada) marca unauthorized e desloga — spec 024 cenário 5', () async {
      final authRepository = AuthRepository.withSession(token: 'fake-token', operator: _testOperator);
      final repository = _repository(_fakeExpiredSessionBackend(), authRepository: authRepository);

      await repository.load();

      expect(repository.status, BusinessSettingsSyncStatus.unauthorized);
      expect(authRepository.isLoggedIn, isFalse);
    });

    test('sem conexão marca networkError e mantém o último valor conhecido — spec 024 cenário 6', () async {
      final repository = _repository(
        _fakeUnreachableBackend(),
        authRepository: AuthRepository.withSession(token: 'fake-token', operator: _testOperator),
      );

      await repository.load();

      expect(repository.status, BusinessSettingsSyncStatus.networkError);
      expect(repository.settings, const BusinessSettings());
    });

    test('500 no load() marca serverError em vez de ficar preso em loading', () async {
      final repository = _repository(
        MockClient((request) async => http.Response(jsonEncode({'error': 'Erro interno'}), 500)),
      );

      await repository.load();

      expect(repository.status, BusinessSettingsSyncStatus.serverError);
      expect(repository.settings, const BusinessSettings());
    });

    test('400 no update() marca serverError sem lançar', () async {
      final repository = _repository(
        MockClient((request) async => http.Response(jsonEncode({'error': 'pixKey inválida'}), 400)),
      );

      await repository.update(const BusinessSettings(merchantName: 'Loja X', merchantCity: 'Recife', pixKey: 'x'));

      expect(repository.status, BusinessSettingsSyncStatus.serverError);
    });

    test('corpo 200 fora do formato esperado marca serverError', () async {
      final repository = _repository(MockClient((request) async => http.Response('<html>proxy</html>', 200)));

      await repository.load();

      expect(repository.status, BusinessSettingsSyncStatus.serverError);
    });
  });

  group('BusinessSettingsCubit', () {
    blocTest<BusinessSettingsCubit, BusinessSettingsState>(
      'save() persists through the Repository and emits the new state',
      build: () => BusinessSettingsCubit(_repository(_fakeBackend())),
      act: (cubit) => cubit.save(merchantName: 'Sonho de Criança', merchantCity: 'Fortaleza', pixKey: '85999998888'),
      expect: () => [
        // Otimista (imediato) e depois confirmado (backend respondeu) — o
        // Repository notifica duas vezes de propósito (spec 024).
        const BusinessSettingsState(
          settings: BusinessSettings(merchantName: 'Sonho de Criança', merchantCity: 'Fortaleza', pixKey: '85999998888'),
        ),
        const BusinessSettingsState(
          settings: BusinessSettings(merchantName: 'Sonho de Criança', merchantCity: 'Fortaleza', pixKey: '85999998888'),
          status: BusinessSettingsSyncStatus.loaded,
        ),
      ],
    );

    test('shares state with AppState.businessSettings when the same Repository instance is injected', () async {
      final repository = _repository(_fakeBackend());
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
