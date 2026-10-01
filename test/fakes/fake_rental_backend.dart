// Fake do backend de locação (spec 026-rental-via-backend) — nenhum
// teste desta fatia bate no backend real. Mesmo contrato do backend
// real: `extend` soma `durationMin` do corpo à duração atual (incremento,
// não total — ver `rental_repository.dart`); `cancel`/`finish` marcam
// `done` (nunca deletam, nunca existiu status "cancelado").

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sonho_de_crianca/data/repositories/auth_repository.dart';
import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/data/services/rental_remote_service.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';

import 'fake_business_settings.dart' show fakeLoggedInAuthRepository;

final _idPath = RegExp(r'^/api/rentals/([^/]+)/(extend|cancel|finish)$');

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

/// `GET` devolve a lista atual (começa em [initial], sem paginação real —
/// uma página só, `nextCursor` sempre `null`, suficiente pros testes
/// desta fatia). `POST` cria; `PATCH .../extend` soma minutos (não
/// substitui); `PATCH .../cancel` e `.../finish` marcam `done`.
/// [blockedToyIds]: `create` devolve 409 pra esse `toyId` (simula "sem
/// unidade livre", spec 001 cenário 3).
http.Client fakeRentalBackend({List<Rental>? initial, Set<String> blockedToyIds = const {}}) {
  var rentals = List.of(initial ?? const <Rental>[]);
  var nextId = 1;
  return MockClient((request) async {
    final path = request.url.path;

    if (request.method == 'GET' && path == '/api/rentals') {
      return _jsonResponse({'items': rentals.map(_toJson).toList(), 'nextCursor': null}, 200);
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

    final match = _idPath.firstMatch(path);
    if (request.method == 'PATCH' && match != null) {
      final id = match.group(1)!;
      final action = match.group(2)!;
      final idx = rentals.indexWhere((r) => r.id == id);
      if (idx == -1) return _jsonResponse({'error': 'não encontrado'}, 404);
      final current = rentals[idx];
      if (current.status != RentalStatus.active) {
        return _jsonResponse({'error': 'Locação não está ativa'}, 409);
      }

      switch (action) {
        case 'extend':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final addMinutes = body['durationMin'] as int;
          current.durationMin = (current.durationMin ?? 0) + addMinutes;
          return _jsonResponse(_toJson(current), 200);
        case 'cancel':
          current.status = RentalStatus.done;
          current.endedAt = DateTime.now();
          return _jsonResponse(_toJson(current), 200);
        case 'finish':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          current.finish(PaymentMethod.values.byName(body['paymentMethod'] as String));
          return _jsonResponse(_toJson(current), 200);
      }
    }

    return _jsonResponse({'error': 'rota não suportada neste fake'}, 404);
  });
}

RentalRemoteService fakeRentalRemoteService({List<Rental>? initial, Set<String> blockedToyIds = const {}}) =>
    RentalRemoteService(ApiClient(httpClient: fakeRentalBackend(initial: initial, blockedToyIds: blockedToyIds)));

RentalRepository fakeRentalRepository({List<Rental>? initial, Set<String> blockedToyIds = const {}, AuthRepository? authRepository}) {
  return RentalRepository(
    service: fakeRentalRemoteService(initial: initial, blockedToyIds: blockedToyIds),
    authRepository: authRepository ?? fakeLoggedInAuthRepository(),
  );
}

/// `withDemoSeed` com backend fake permissivo + sessão real já logada —
/// mesma conveniência de [fakeRentalRepository], pros testes que
/// precisam das 11 locações de demonstração. O backend fake é semeado com
/// os **mesmos** ids (`a1`-`a3`/`h1`-`h8`) que `withDemoSeed` usa pra
/// `rentals` local — sem isso, `extend`/`cancel`/`finish` numa locação
/// seedada bateria 404 contra um "servidor" vazio.
RentalRepository fakeSeededRentalRepository({AuthRepository? authRepository}) {
  return RentalRepository.withDemoSeed(
    service: fakeRentalRemoteService(initial: RentalRepository.demoSeedForTest()),
    authRepository: authRepository ?? fakeLoggedInAuthRepository(),
  );
}
