// Fake do backend de catálogo (spec 025-catalogo-sessao-dispositivo) —
// nenhum teste desta fatia bate no backend real. O fake não checa token
// nenhum por padrão (a maioria dos testes só precisa de um `ToyRepository`
// funcional, não está testando a guarda de sessão em si — essa tem teste
// dedicado em `toy_repository_test.dart`).

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sonho_de_crianca/data/repositories/auth_repository.dart';
import 'package:sonho_de_crianca/data/repositories/toy_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/data/services/toy_remote_service.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/theme/app_colors.dart';

import 'fake_business_settings.dart' show fakeLoggedInAuthRepository;

final _idPath = RegExp(r'^/api/toys/(.+)$');

/// `http.Response` com `content-type: application/json` — sem isso, a
/// codificação cai no default (`latin1`), que rejeita caracteres como "—"
/// nas mensagens de erro em português (`http.Response` decide a
/// codificação pelo header, não tem parâmetro `encoding` direto).
http.Response _jsonResponse(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> _toJson(Toy t) => {
      'id': t.id,
      'name': t.name,
      'qty': t.qty,
      'blockMin': t.blockMin,
      'price': t.price,
      'ink': t.ink.name,
      'imageKey': t.imageKey,
      'category': t.category.name,
    };

/// `GET` devolve a lista atual (começa em [initial]); `POST` cria (gera um
/// id sequencial fake); `PATCH` atualiza `price`/`blockMin`; `DELETE`
/// remove, ou devolve 409 se o id estiver em [blockedIds] (simula
/// brinquedo com `Rental` vinculado, spec 001 cenário 6).
http.Client fakeToyBackend({List<Toy>? initial, Set<String> blockedIds = const {}}) {
  var toys = List<Toy>.of(initial ?? const []);
  var nextId = 1;
  return MockClient((request) async {
    final path = request.url.path;

    if (request.method == 'GET' && path == '/api/toys') {
      return _jsonResponse(toys.map(_toJson).toList(), 200);
    }

    if (request.method == 'POST' && path == '/api/toys') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final toy = Toy(
        id: 'fake-toy-${nextId++}',
        name: body['name'] as String,
        qty: body['qty'] as int,
        blockMin: body['blockMin'] as int,
        price: (body['price'] as num).toDouble(),
        ink: ToyInk.values.byName(body['ink'] as String),
        imageKey: body['imageKey'] as String,
        category: ToyCategory.values.byName(body['category'] as String),
      );
      toys = [...toys, toy];
      return _jsonResponse(_toJson(toy), 201);
    }

    final idMatch = _idPath.firstMatch(path);
    if (request.method == 'PATCH' && idMatch != null) {
      final id = idMatch.group(1)!;
      final idx = toys.indexWhere((t) => t.id == id);
      if (idx == -1) return _jsonResponse({'error': 'não encontrado'}, 404);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final current = toys[idx];
      final updated = current.copyWith(
        price: body['price'] != null ? (body['price'] as num).toDouble() : null,
        blockMin: body['blockMin'] != null ? body['blockMin'] as int : null,
      );
      toys = [...toys]..[idx] = updated;
      return _jsonResponse(_toJson(updated), 200);
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

ToyRepository fakeToyRepository({List<Toy>? initial, Set<String> blockedIds = const {}, AuthRepository? authRepository}) {
  return ToyRepository(
    service: ToyRemoteService(ApiClient(httpClient: fakeToyBackend(initial: initial, blockedIds: blockedIds))),
    authRepository: authRepository ?? fakeLoggedInAuthRepository(),
  );
}
