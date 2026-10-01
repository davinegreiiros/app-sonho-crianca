// Tests for spec 013 (fundação, `withDemoSeed`/notify-on-mutation) +
// spec 026-rental-via-backend (sincronização com o backend): leitura usa
// a sessão de dispositivo (cenário 1, sem exigir operador real), escrita
// exige sessão real (cenário 3), falha de leitura mantém o cache sem
// avisar ninguém (cenário 5), 409 de concorrência chega com reversão
// (cenário 6), e dois `RentalRepository` enxergam a mesma mudança através
// do mesmo backend fake (cenário 2). `ApiClient` roda contra `MockClient`
// — nenhum teste bate no backend real.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/auth_repository.dart';
import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/data/services/api_exceptions.dart';
import 'package:sonho_de_crianca/data/services/rental_remote_service.dart';
import 'package:sonho_de_crianca/domain/models/operator.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/state/app_state.dart';

import 'fakes/fake_rental_backend.dart';
import 'fakes/fake_rental_notifier.dart';
import 'fakes/fake_secure_storage.dart';

const _humanOperator = Operator(id: 'op1', name: 'Maria', username: 'maria');
const _deviceToken = 'fake-device-token';
const _operatorToken = 'fake-operator-token';

http.Response _jsonResponse(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> _toJson(Rental r) => {
      'id': r.id,
      'toyId': r.toyId,
      'childName': r.childName,
      'guardianName': r.guardianName,
      'guardianPhone': r.guardianPhone,
      'startedAt': r.startedAt.toUtc().toIso8601String(),
      'durationMin': r.durationMin,
      'ratePerMinute': r.ratePerMinute,
      'price': r.price,
      'status': r.status.name,
      'endedAt': r.endedAt?.toUtc().toIso8601String(),
      'paymentMethod': r.paymentMethod?.name,
    };

/// Backend fake que *checa* o token: só aceita [_deviceToken] em `GET`
/// (leitura, cenário 1) e só aceita [_operatorToken] em `POST`/`PATCH`
/// (escrita, cenário 3) — qualquer outro token (ou nenhum) vira 401,
/// mesmo contrato do backend real. Mesma técnica de `toy_repository_test
/// .dart` (spec 025): reimplementa as rotas (não envolve
/// `fakeRentalBackend`, que não checa token nenhum).
http.Client _authAwareBackend({List<Rental>? initial, Set<String> blockedToyIds = const {}}) {
  var rentals = List.of(initial ?? const <Rental>[]);
  var nextId = 1;
  return MockClient((request) async {
    final auth = request.headers['authorization'];
    final path = request.url.path;

    if (request.method == 'GET' && path == '/api/rentals') {
      if (auth != 'Bearer $_deviceToken') {
        return _jsonResponse({'error': 'Token inválido ou expirado'}, 401);
      }
      return _jsonResponse({'items': rentals.map(_toJson).toList(), 'nextCursor': null}, 200);
    }

    if (auth != 'Bearer $_operatorToken') {
      return _jsonResponse({'error': 'Não autenticado'}, 401);
    }

    if (request.method == 'POST' && path == '/api/rentals') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final toyId = body['toyId'] as String;
      if (blockedToyIds.contains(toyId)) {
        return _jsonResponse({'error': 'Nenhuma unidade disponível'}, 409);
      }
      final rental = Rental(
        id: 'fake-rental-${nextId++}',
        toyId: toyId,
        childName: body['childName'] as String,
        guardianName: body['guardianName'] as String,
        guardianPhone: body['guardianPhone'] as String,
        startedAt: DateTime.parse(body['startedAt'] as String).toLocal(),
        durationMin: body['durationMin'] as int?,
        ratePerMinute: (body['ratePerMinute'] as num?)?.toDouble(),
        price: (body['price'] as num).toDouble(),
        status: RentalStatus.active,
      );
      rentals = [...rentals, rental];
      return _jsonResponse(_toJson(rental), 201);
    }

    final match = RegExp(r'^/api/rentals/([^/]+)/(extend|cancel|finish)$').firstMatch(path);
    if (request.method == 'PATCH' && match != null) {
      final id = match.group(1)!;
      final action = match.group(2)!;
      final idx = rentals.indexWhere((r) => r.id == id);
      if (idx == -1) return _jsonResponse({'error': 'não encontrado'}, 404);
      final current = rentals[idx];
      switch (action) {
        case 'extend':
          final addMinutes = (jsonDecode(request.body) as Map<String, dynamic>)['durationMin'] as int;
          current.durationMin = (current.durationMin ?? 0) + addMinutes;
          return _jsonResponse(_toJson(current), 200);
        case 'cancel':
          current.status = RentalStatus.done;
          current.endedAt = DateTime.now();
          return _jsonResponse(_toJson(current), 200);
        case 'finish':
          final paymentMethod = (jsonDecode(request.body) as Map<String, dynamic>)['paymentMethod'] as String;
          current.status = RentalStatus.done;
          current.endedAt = DateTime.now();
          current.paymentMethod = PaymentMethod.values.byName(paymentMethod);
          return _jsonResponse(_toJson(current), 200);
      }
    }

    return _jsonResponse({'error': 'rota não suportada neste fake'}, 404);
  });
}

RentalRepository _repository(http.Client client, {bool operatorLoggedIn = false}) {
  final authRepository = operatorLoggedIn
      ? AuthRepository.withSession(token: _operatorToken, operator: _humanOperator)
      : AuthRepository();
  return RentalRepository(service: RentalRemoteService(ApiClient(httpClient: client)), authRepository: authRepository);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  setUp(setUpFakeSecureStorage);

  group('withDemoSeed()', () {
    test('seeds the same 11 rentals AppState used to (3 active, 8 done)', () {
      final repository = RentalRepository.withDemoSeed(
        service: RentalRemoteService(ApiClient(httpClient: fakeRentalBackend())),
        authRepository: AuthRepository(),
      );

      expect(repository.rentals, hasLength(11));
      expect(repository.rentals.map((r) => r.id), containsAll(['a1', 'a2', 'a3', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'h7', 'h8']));
      expect(repository.rentals.where((r) => r.status == RentalStatus.active), hasLength(3));
      expect(repository.rentals.where((r) => r.status == RentalStatus.done), hasLength(8));
    });
  });

  group('load() — sessão de dispositivo (cenário 1)', () {
    test('lê o histórico sem sessão de operador real', () async {
      final seedRental = Rental(id: 'seed-1', toyId: 'carrinho', childName: 'A', guardianName: 'B', startedAt: DateTime.now(), durationMin: 15, price: 10, status: RentalStatus.active);
      final authRepository = _FakeDeviceAuth(deviceToken: _deviceToken);
      final repository = RentalRepository(
        service: RentalRemoteService(ApiClient(httpClient: _authAwareBackend(initial: [seedRental]))),
        authRepository: authRepository,
      );

      await repository.load();

      expect(repository.rentals, hasLength(1));
      expect(authRepository.isLoggedIn, isFalse);
    });
  });

  group('load() — falha (cenário 5)', () {
    test('sem deviceToken configurado, mantém o histórico seed sem erro', () async {
      final repository = _repository(_authAwareBackend());
      final before = repository.rentals;

      await repository.load();

      expect(repository.rentals, before);
    });

    test('backend fora do ar mantém o histórico em cache', () async {
      final authWithDevice = _FakeDeviceAuth(deviceToken: _deviceToken);
      final repository = RentalRepository(
        service: RentalRemoteService(ApiClient(httpClient: MockClient((_) async => throw http.ClientException('sem rede (fake)')))),
        authRepository: authWithDevice,
      );
      final before = repository.rentals;

      await repository.load();

      expect(repository.rentals, before);
    });
  });

  group('addNew() — exige sessão de operador real (cenário 3)', () {
    test('sem sessão real lança ApiUnauthorizedException', () async {
      final repository = _repository(_authAwareBackend());

      await expectLater(
        () => repository.addNew(
          toyId: 'carrinho',
          childName: 'Teste',
          guardianName: 'Responsável',
          guardianPhone: '',
          durationMin: 15,
          price: 10,
          ratePerMinute: null,
        ),
        throwsA(isA<ApiUnauthorizedException>()),
      );
      expect(repository.rentals, isEmpty); // nunca tentou o backend
    });

    test('com sessão real cria e aparece em rentals, com o rótulo de quem está no posto', () async {
      final repository = _repository(_authAwareBackend(), operatorLoggedIn: true);

      // `createdByMonitorName` é o nome digitado em "Quem é você hoje"
      // (spec 023), não o operador logado (spec 026 — "login fica só
      // com o administrador": a sessão real só autentica a escrita,
      // nunca representa quem está de fato no posto).
      final rental = await repository.addNew(
        toyId: 'carrinho',
        childName: 'Teste',
        guardianName: 'Responsável',
        guardianPhone: '',
        durationMin: 15,
        price: 10,
        ratePerMinute: null,
        createdByMonitorName: 'Gustavo',
      );

      expect(repository.rentals.any((r) => r.id == rental.id), isTrue);
      expect(rental.createdByMonitorName, 'Gustavo');
    });
  });

  group('extend()/cancel()/finish() — exigem sessão de operador real', () {
    test('extend() sem sessão real lança e não altera nada', () async {
      final seedRental = Rental(id: 'r1', toyId: 'carrinho', childName: 'A', guardianName: 'B', startedAt: DateTime.now(), durationMin: 15, price: 10, status: RentalStatus.active);
      final repository = _repository(_authAwareBackend(), operatorLoggedIn: false);
      repository.rentals.add(seedRental);

      await expectLater(
        () => repository.extend(seedRental.id, durationMin: 30, price: 20),
        throwsA(isA<ApiUnauthorizedException>()),
      );
      expect(seedRental.durationMin, 15); // nunca tentou o backend, nunca mudou
    });

    test('extend() envia o incremento, não o total absoluto', () async {
      final seedRental = Rental(id: 'r1', toyId: 'carrinho', childName: 'A', guardianName: 'B', startedAt: DateTime.now(), durationMin: 15, price: 10, status: RentalStatus.active);
      late int sentAddMinutes;
      final client = MockClient((request) async {
        if (request.method == 'PATCH' && request.url.path.endsWith('/extend')) {
          sentAddMinutes = (jsonDecode(request.body) as Map<String, dynamic>)['durationMin'] as int;
          return _jsonResponse({
            'id': seedRental.id,
            'toyId': seedRental.toyId,
            'childName': seedRental.childName,
            'guardianName': seedRental.guardianName,
            'guardianPhone': '',
            'startedAt': seedRental.startedAt.toUtc().toIso8601String(),
            'durationMin': 15 + sentAddMinutes,
            'ratePerMinute': null,
            'price': 20,
            'status': 'active',
            'endedAt': null,
            'paymentMethod': null,
          }, 200);
        }
        return _jsonResponse({'error': 'rota não suportada'}, 404);
      });
      final repository = _repository(client, operatorLoggedIn: true);
      repository.rentals.add(seedRental);

      await repository.extend(seedRental.id, durationMin: 25, price: 20);

      expect(sentAddMinutes, 10); // 25 (novo total) - 15 (anterior) = 10, não 25
    });

    test('cancel() marca done sem pagamento (não remove) — achado da spec 026', () async {
      final seedRental = Rental(id: 'r1', toyId: 'carrinho', childName: 'A', guardianName: 'B', startedAt: DateTime.now(), durationMin: 15, price: 10, status: RentalStatus.active);
      final repository = _repository(_authAwareBackend(initial: [seedRental]), operatorLoggedIn: true);
      repository.rentals.add(seedRental);

      await repository.cancel(seedRental.id);

      expect(repository.rentals, contains(seedRental)); // ainda na lista
      expect(seedRental.status, RentalStatus.done);
      expect(seedRental.paymentMethod, isNull); // nunca conta como receita (Rental.isCompleted)
      expect(seedRental.isCompleted, isFalse);
    });
  });

  group('sincronização entre "aparelhos" (cenário 2)', () {
    test('um RentalRepository cria, outro vê ao recarregar', () async {
      final client = _authAwareBackend(initial: []);
      final repoA = RentalRepository(
        service: RentalRemoteService(ApiClient(httpClient: client)),
        authRepository: AuthRepository.withSession(token: _operatorToken, operator: _humanOperator),
      );
      final repoB = RentalRepository(
        service: RentalRemoteService(ApiClient(httpClient: client)),
        authRepository: _FakeDeviceAuth(deviceToken: _deviceToken),
      );

      await repoA.addNew(toyId: 'carrinho', childName: 'Compartilhado', guardianName: 'B', guardianPhone: '', durationMin: 15, price: 10, ratePerMinute: null);
      await repoB.load();

      expect(repoB.rentals.any((r) => r.childName == 'Compartilhado'), isTrue);
    });
  });

  group('concorrência — última unidade (cenário 6)', () {
    test('409 do backend reverte a criação otimista e propaga a mensagem', () async {
      final repository = _repository(_authAwareBackend(blockedToyIds: {'carrinho'}), operatorLoggedIn: true);

      await expectLater(
        () => repository.addNew(toyId: 'carrinho', childName: 'Sem vaga', guardianName: 'B', guardianPhone: '', durationMin: 15, price: 10, ratePerMinute: null),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('disponível'))),
      );
      expect(repository.rentals, isEmpty); // nunca chegou a aparecer
    });
  });

  test('AppState.rentals reflects the same Repository instance when injected', () async {
    final repository = _repository(_authAwareBackend(), operatorLoggedIn: true);
    final state = AppState(notifications: FakeRentalNotifier(), rentalRepository: repository);

    final rental = await repository.addNew(toyId: 'carrinho', childName: 'Teste', guardianName: 'B', guardianPhone: '', durationMin: 15, price: 10, ratePerMinute: null);

    // Same Repository instance -> AppState sees the change immediately,
    // no separate/divergent copy of the list.
    expect(state.rentals, repository.rentals);
    expect(state.rentals.any((r) => r.id == rental.id), isTrue);

    state.dispose();
  });
}

/// `AuthRepository` de teste com `deviceToken` pronto, sem tocar
/// storage/rede — mesma técnica de `toy_repository_test.dart` (spec 025).
class _FakeDeviceAuth extends AuthRepository {
  _FakeDeviceAuth({required String deviceToken}) : _fakeDeviceToken = deviceToken;

  final String _fakeDeviceToken;

  @override
  String? get deviceToken => _fakeDeviceToken;
}
