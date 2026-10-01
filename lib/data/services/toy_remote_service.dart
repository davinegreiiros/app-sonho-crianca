import '../../domain/models/toy.dart';
import '../../theme/app_colors.dart' show ToyInk;
import 'api_client.dart';

/// Sucessor de `ToyLocalService` (spec 025-catalogo-sessao-dispositivo) —
/// por baixo chama o backend em vez de SQLite. `token` vem de
/// `AuthRepository` a cada chamada (não guardado aqui — stateless, mesma
/// regra da constitution pra `lib/data/services/`): leitura usa o token de
/// dispositivo, escrita usa o de operador real — quem decide qual é o
/// `ToyRepository`, não este Service.
class ToyRemoteService {
  const ToyRemoteService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Toy>> loadAll({required String? token}) async {
    final json = await _apiClient.get('/api/toys', token: token) as List<dynamic>;
    return json.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Toy> create({
    required String name,
    required int qty,
    required int blockMin,
    required double price,
    required ToyInk ink,
    required String imageKey,
    required ToyCategory category,
    required String? token,
  }) async {
    final json = await _apiClient.post(
      '/api/toys',
      token: token,
      body: {
        'name': name,
        'qty': qty,
        'blockMin': blockMin,
        'price': price,
        'ink': ink.name,
        'imageKey': imageKey,
        'category': category.name,
      },
    ) as Map<String, dynamic>;
    return _fromJson(json);
  }

  /// Backend só aceita `price`/`blockMin` em `PATCH /api/toys/:id` (mesmo
  /// teto de `ToyRepository`, que nunca editou mais que isso).
  Future<Toy> updatePrice(String id, double price, {required String? token}) =>
      _patch(id, {'price': price}, token: token);

  Future<Toy> updateBlockMin(String id, int blockMin, {required String? token}) =>
      _patch(id, {'blockMin': blockMin}, token: token);

  Future<Toy> _patch(String id, Map<String, Object?> body, {required String? token}) async {
    final json = await _apiClient.patch('/api/toys/$id', token: token, body: body) as Map<String, dynamic>;
    return _fromJson(json);
  }

  Future<void> remove(String id, {required String? token}) {
    return _apiClient.delete('/api/toys/$id', token: token);
  }

  Toy _fromJson(Map<String, dynamic> json) => Toy(
        id: json['id'] as String,
        name: json['name'] as String,
        qty: json['qty'] as int,
        blockMin: json['blockMin'] as int,
        price: (json['price'] as num).toDouble(),
        ink: ToyInk.values.byName(json['ink'] as String),
        imageKey: json['imageKey'] as String,
        category: ToyCategory.values.byName(json['category'] as String),
      );
}
