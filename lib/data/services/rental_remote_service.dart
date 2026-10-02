import '../../domain/models/rental.dart';
import 'api_client.dart';

/// Sucessor de `RentalLocalService` (spec 026-rental-via-backend) — por
/// baixo chama o backend em vez de SQLite. `token` vem de `AuthRepository`
/// a cada chamada (stateless, mesma regra de `ToyRemoteService`) — sempre
/// a sessão do administrador (spec 027-login-admin-sessao).
///
/// `createdByOperatorId`/`finishedByOperatorId` do backend (auditoria por
/// id) não têm campo equivalente aqui — `Rental.createdByMonitorName`/
/// `finishedByMonitorName` são só exibição local, preenchidos por quem
/// chama (`RentalRepository`) com o nome do operador agindo agora, nunca
/// desserializados do backend (não existe endpoint pra resolver id→nome).
class RentalRemoteService {
  const RentalRemoteService(this._apiClient);

  final ApiClient _apiClient;

  static const _pageLimit = 200;

  /// Percorre todas as páginas do cursor do backend (teto de 200 por
  /// página) e devolve a lista completa — sem UI de "carregar mais" nesta
  /// fatia (ver `plan.md`, "Riscos", pra quando isso parar de bastar).
  Future<List<Rental>> loadAll({required String? token}) async {
    final all = <Rental>[];
    String? cursor;
    while (true) {
      final query = cursor == null ? '' : '&cursor=$cursor';
      final json = await _apiClient.get('/api/rentals?limit=$_pageLimit$query', token: token) as Map<String, dynamic>;
      final items = json['items'] as List<dynamic>;
      all.addAll(items.map((e) => _fromJson(e as Map<String, dynamic>)));
      cursor = json['nextCursor'] as String?;
      if (cursor == null) break;
    }
    return all;
  }

  Future<Rental> create({
    required String toyId,
    required String childName,
    required String guardianName,
    required String guardianPhone,
    required DateTime startedAt,
    required int? durationMin,
    required double? ratePerMinute,
    required double price,
    required String? token,
  }) async {
    final json = await _apiClient.post(
      '/api/rentals',
      token: token,
      body: {
        'toyId': toyId,
        'childName': childName,
        'guardianName': guardianName,
        'guardianPhone': guardianPhone,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'durationMin': durationMin,
        'ratePerMinute': ratePerMinute,
        'price': price,
      },
    ) as Map<String, dynamic>;
    return _fromJson(json);
  }

  Future<Rental> extend(String id, int durationMin, {required String? token}) async {
    final json = await _apiClient.patch(
      '/api/rentals/$id/extend',
      token: token,
      body: {'durationMin': durationMin},
    ) as Map<String, dynamic>;
    return _fromJson(json);
  }

  Future<Rental> cancel(String id, {required String? token}) async {
    final json = await _apiClient.patch('/api/rentals/$id/cancel', token: token) as Map<String, dynamic>;
    return _fromJson(json);
  }

  /// [finalPrice]: valor final de locação de tempo corrido (nasce com
  /// `price: 0` no backend) — sem ele o backend gravaria R$ 0 e o turno/
  /// painel do servidor perderiam esse valor (backend#003, bugfix
  /// 2026-10-02). Nunca mandar pra duração fixa (backend responde 400).
  Future<Rental> finish(String id, PaymentMethod paymentMethod, {double? finalPrice, required String? token}) async {
    final json = await _apiClient.patch(
      '/api/rentals/$id/finish',
      token: token,
      body: {
        'paymentMethod': paymentMethod.name,
        if (finalPrice != null) 'finalPrice': finalPrice,
      },
    ) as Map<String, dynamic>;
    return _fromJson(json);
  }

  Rental _fromJson(Map<String, dynamic> json) => Rental(
        id: json['id'] as String,
        toyId: json['toyId'] as String,
        childName: json['childName'] as String,
        guardianName: json['guardianName'] as String,
        guardianPhone: json['guardianPhone'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
        durationMin: json['durationMin'] as int?,
        ratePerMinute: (json['ratePerMinute'] as num?)?.toDouble(),
        price: (json['price'] as num).toDouble(),
        status: RentalStatus.values.byName(json['status'] as String),
        endedAt: json['endedAt'] == null ? null : DateTime.parse(json['endedAt'] as String).toLocal(),
        paymentMethod: json['paymentMethod'] == null ? null : PaymentMethod.values.byName(json['paymentMethod'] as String),
      );
}
