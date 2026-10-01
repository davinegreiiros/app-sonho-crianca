// Tests for spec 025-catalogo-sessao-dispositivo: leitura do catálogo usa
// a sessão de dispositivo (sem exigir operador logado — cenário 1),
// escrita exige sessão real (cenário 3), falha de dispositivo mantém o
// cache sem avisar ninguém (cenário 4), 409 do backend chega com a
// mensagem pronta (cenário 5), e dois `ToyRepository` enxergam a mesma
// mudança através do mesmo backend fake (cenário 2). `ApiClient` roda
// contra `MockClient` — nenhum teste bate no backend real.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sonho_de_crianca/data/repositories/auth_repository.dart';
import 'package:sonho_de_crianca/data/repositories/toy_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/data/services/api_exceptions.dart';
import 'package:sonho_de_crianca/data/services/toy_remote_service.dart';
import 'package:sonho_de_crianca/domain/models/operator.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/theme/app_colors.dart';

import 'fakes/fake_secure_storage.dart';

const _humanOperator = Operator(id: 'op1', name: 'Maria', username: 'maria');
const _deviceToken = 'fake-device-token';
const _operatorToken = 'fake-operator-token';

final _seedToy = Toy(
  id: 'seed-1',
  name: 'Carrinho',
  qty: 2,
  blockMin: 15,
  price: 10,
  ink: ToyInk.cyan,
  imageKey: 'carrinho',
  category: ToyCategory.eletrico,
);

Map<String, dynamic> _toyJson(Toy t) => {
      'id': t.id,
      'name': t.name,
      'qty': t.qty,
      'blockMin': t.blockMin,
      'price': t.price,
      'ink': t.ink.name,
      'imageKey': t.imageKey,
      'category': t.category.name,
    };

/// Backend fake que *checa* o token: só aceita [_deviceToken] em `GET`
/// (leitura, cenário 1) e só aceita [_operatorToken] em `POST`/`PATCH`/
/// `DELETE` (escrita, cenário 3) — qualquer outro token (ou nenhum) vira
/// 401, igual o backend real faria pra uma sessão errada/ausente.
/// `http.Response` com `content-type: application/json` — sem isso, a
/// codificação cai no default (`latin1`), que rejeita caracteres como "—"
/// nas mensagens de erro em português (`http.Response` decide a
/// codificação pelo header, não tem parâmetro `encoding` direto).
http.Response _jsonResponse(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

http.Client _authAwareBackend({List<Toy>? initial, Set<String> blockedIds = const {}}) {
  var toys = List<Toy>.of(initial ?? [_seedToy]);
  return MockClient((request) async {
    final auth = request.headers['authorization'];
    final path = request.url.path;

    if (request.method == 'GET' && path == '/api/toys') {
      if (auth != 'Bearer $_deviceToken') {
        return _jsonResponse({'error': 'Token inválido ou expirado'}, 401);
      }
      return _jsonResponse(toys.map(_toyJson).toList(), 200);
    }

    if (auth != 'Bearer $_operatorToken') {
      return _jsonResponse({'error': 'Não autenticado'}, 401);
    }

    if (request.method == 'POST' && path == '/api/toys') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final toy = Toy(
        id: 'new-${toys.length + 1}',
        name: body['name'] as String,
        qty: body['qty'] as int,
        blockMin: body['blockMin'] as int,
        price: (body['price'] as num).toDouble(),
        ink: ToyInk.values.byName(body['ink'] as String),
        imageKey: body['imageKey'] as String,
        category: ToyCategory.values.byName(body['category'] as String),
      );
      toys = [...toys, toy];
      return _jsonResponse(_toyJson(toy), 201);
    }

    final idMatch = RegExp(r'^/api/toys/(.+)$').firstMatch(path);
    if (request.method == 'PATCH' && idMatch != null) {
      final id = idMatch.group(1)!;
      final idx = toys.indexWhere((t) => t.id == id);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final current = toys[idx];
      final updated = current.copyWith(
        price: body['price'] != null ? (body['price'] as num).toDouble() : null,
        blockMin: body['blockMin'] != null ? body['blockMin'] as int : null,
      );
      toys = [...toys]..[idx] = updated;
      return _jsonResponse(_toyJson(updated), 200);
    }

    if (request.method == 'DELETE' && idMatch != null) {
      final id = idMatch.group(1)!;
      if (blockedIds.contains(id)) {
        return _jsonResponse({'error': 'Brinquedo tem locações vinculadas — não pode ser removido'}, 409);
      }
      toys = toys.where((t) => t.id != id).toList();
      return http.Response('', 204);
    }

    return _jsonResponse({'error': 'rota não suportada neste fake'}, 404);
  });
}

/// Sessão de operador real — `operatorLoggedIn: false` devolve uma
/// `AuthRepository` nova (sem token nenhum, nem de operador nem de
/// dispositivo), pra testar mutação/leitura sem sessão.
ToyRepository _repository(http.Client client, {bool operatorLoggedIn = false}) {
  final authRepository = operatorLoggedIn
      ? AuthRepository.withSession(token: _operatorToken, operator: _humanOperator)
      : AuthRepository();
  return ToyRepository(
    service: ToyRemoteService(ApiClient(httpClient: client)),
    authRepository: authRepository,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(setUpFakeSecureStorage);

  group('load() — sessão de dispositivo (cenário 1)', () {
    test('lê o catálogo sem sessão de operador real', () async {
      final deviceAuth = _FakeDeviceAuth(deviceToken: _deviceToken);
      final repository = ToyRepository(
        service: ToyRemoteService(ApiClient(httpClient: _authAwareBackend())),
        authRepository: deviceAuth,
      );

      await repository.load();

      expect(repository.toys, hasLength(1));
      expect(repository.toys.first.name, 'Carrinho');
      // A sessão de operador real nunca entrou em jogo.
      expect(deviceAuth.isLoggedIn, isFalse);
    });
  });

  group('load() — falha de dispositivo (cenário 4)', () {
    test('sem deviceToken configurado, mantém o catálogo seed sem erro', () async {
      final repository = _repository(_authAwareBackend());
      final before = repository.toys;

      await repository.load();

      expect(repository.toys, before); // nada mudou, nenhuma exceção subiu
    });

    test('backend fora do ar mantém o catálogo em cache', () async {
      final authWithDevice = _FakeDeviceAuth(deviceToken: _deviceToken);
      final repository = ToyRepository(
        service: ToyRemoteService(ApiClient(httpClient: MockClient((_) async => throw http.ClientException('sem rede (fake)')))),
        authRepository: authWithDevice,
      );
      final before = repository.toys;

      await repository.load();

      expect(repository.toys, before);
    });
  });

  group('mutações — exigem sessão de operador real (cenário 3)', () {
    test('addNew() sem sessão real lança ApiUnauthorizedException', () async {
      final repository = _repository(_authAwareBackend());

      await expectLater(
        () => repository.addNew(
          name: 'Novo',
          price: 10,
          blockMin: 15,
          ink: ToyInk.cyan,
          imageKey: 'outro',
          category: ToyCategory.outro,
        ),
        throwsA(isA<ApiUnauthorizedException>()),
      );
    });

    test('addNew() com sessão real cria e aparece em toys', () async {
      final repository = _repository(_authAwareBackend(), operatorLoggedIn: true);

      final toy = await repository.addNew(
        name: 'Novo',
        price: 10,
        blockMin: 15,
        ink: ToyInk.cyan,
        imageKey: 'outro',
        category: ToyCategory.outro,
      );

      expect(repository.toys.any((t) => t.id == toy.id), isTrue);
    });

    test('updatePrice() sem sessão real reverte o valor otimista', () async {
      // Sem `load()`, `repository.toys` é o seed padrão (`kInitialToys`) —
      // o `initial` do backend fake só importa pra quem der `load()`.
      final repository = _repository(_authAwareBackend());
      final target = repository.toys.first;
      final originalPrice = target.price;

      await expectLater(
        () => repository.updatePrice(target.id, 999),
        throwsA(isA<ApiUnauthorizedException>()),
      );

      expect(repository.toys.firstWhere((t) => t.id == target.id).price, originalPrice);
    });
  });

  group('remove() — 409 com a mensagem do backend (cenário 5)', () {
    test('brinquedo com Rental vinculado mostra a mensagem pronta e não remove', () async {
      // Sem `load()`, `repository.toys` é o seed padrão (`kInitialToys`) —
      // bloqueia esse mesmo id no backend fake.
      final blockedId = kInitialToys.first.id;
      final repository = _repository(_authAwareBackend(blockedIds: {blockedId}), operatorLoggedIn: true);

      await expectLater(
        () => repository.remove(blockedId),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('locações vinculadas'))),
      );
      expect(repository.toys.any((t) => t.id == blockedId), isTrue); // reversão
    });
  });

  group('sincronização entre "aparelhos" (cenário 2)', () {
    test('um ToyRepository cria, outro vê ao recarregar', () async {
      final client = _authAwareBackend(initial: []);
      final repoA = ToyRepository(
        service: ToyRemoteService(ApiClient(httpClient: client)),
        authRepository: AuthRepository.withSession(token: _operatorToken, operator: _humanOperator),
      );
      final repoB = ToyRepository(
        service: ToyRemoteService(ApiClient(httpClient: client)),
        authRepository: _FakeDeviceAuth(deviceToken: _deviceToken),
      );

      await repoA.addNew(
        name: 'Compartilhado',
        price: 20,
        blockMin: 10,
        ink: ToyInk.magenta,
        imageKey: 'outro',
        category: ToyCategory.outro,
      );
      await repoB.load();

      expect(repoB.toys.any((t) => t.name == 'Compartilhado'), isTrue);
    });
  });
}

/// `AuthRepository` de teste com `deviceToken` pronto, sem tocar
/// storage/rede — `AuthRepository` real só preenche `deviceToken` via
/// `loginDevice()` (que bate numa rota de login, não é o que estes testes
/// de leitura querem simular).
class _FakeDeviceAuth extends AuthRepository {
  _FakeDeviceAuth({required String deviceToken}) : _fakeDeviceToken = deviceToken;

  final String _fakeDeviceToken;

  @override
  String? get deviceToken => _fakeDeviceToken;
}
