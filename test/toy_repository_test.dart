// Tests for spec 025-catalogo-sessao-dispositivo (sessão revista na
// 027-login-admin-sessao): leitura do catálogo usa a sessão do
// administrador, sem sessão não chama nada, 401 derruba a sessão,
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

import 'fakes/fake_session_storage.dart';

const _humanOperator = Operator(id: 'op1', name: 'Maria', username: 'maria');
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

/// Backend fake que *checa* o token: só aceita [_operatorToken] (sessão
/// do administrador, spec 027) em leitura e escrita — qualquer outro token
/// (ou nenhum) vira 401, igual o backend real faria pra uma sessão
/// errada/ausente.
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
      if (auth != 'Bearer $_operatorToken') {
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

/// Sessão do administrador — a única que existe desde a spec
/// 027-login-admin-sessao (leitura e escrita usam o mesmo token).
AuthRepository _adminAuth({String token = _operatorToken}) => AuthRepository.withSession(token: token, operator: _humanOperator);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(setUpFakeSessionStorage);

  group('load() — sessão do administrador (spec 027)', () {
    test('lê o catálogo com o token do administrador', () async {
      final repository = ToyRepository(
        service: ToyRemoteService(ApiClient(httpClient: _authAwareBackend())),
        authRepository: _adminAuth(),
      );

      await repository.load();

      expect(repository.toys, hasLength(1));
      expect(repository.toys.first.name, 'Carrinho');
    });

    test('sem sessão, não chama o backend e mantém o catálogo seed', () async {
      var calls = 0;
      final repository = ToyRepository(
        service: ToyRemoteService(ApiClient(httpClient: MockClient((_) async {
          calls++;
          return http.Response('[]', 200);
        }))),
        authRepository: AuthRepository(),
      );
      final before = repository.toys;

      await repository.load();

      expect(calls, 0);
      expect(repository.toys, before);
    });

    test('401 na leitura mantém o cache e derruba a sessão (cenário 8)', () async {
      final auth = _adminAuth(token: 'token-revogado');
      final repository = ToyRepository(
        service: ToyRemoteService(ApiClient(httpClient: _authAwareBackend())),
        authRepository: auth,
      );
      final before = repository.toys;

      await repository.load();

      expect(repository.toys, before);
      expect(auth.isLoggedIn, isFalse);
    });

    test('backend fora do ar mantém o catálogo em cache e a sessão', () async {
      final auth = _adminAuth();
      final repository = ToyRepository(
        service: ToyRemoteService(ApiClient(httpClient: MockClient((_) async => throw http.ClientException('sem rede (fake)')))),
        authRepository: auth,
      );
      final before = repository.toys;

      await repository.load();

      expect(repository.toys, before);
      expect(auth.isLoggedIn, isTrue);
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
        authRepository: _adminAuth(),
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
