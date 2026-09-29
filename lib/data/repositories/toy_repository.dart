import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';

import '../../domain/models/toy.dart';
import '../../theme/app_colors.dart' show ToyInk;
import '../services/toy_local_service.dart';

/// Single source of truth for the toy catalog (spec
/// 012-migracao-catalogo-criacao) — one shared instance (wired in
/// `main.dart`) consumed both by `ToyCatalogCubit` (new world,
/// `lib/ui/features/catalog/`) and by `AppState.toys`/`toyById`/etc. (old
/// world, kept as a thin proxy).
///
/// Persistência (spec 020-persistencia-local): [_localService], quando
/// injetado (sempre o caso em `main.dart`; `null` em ~30 arquivos de teste
/// que não precisam de banco real), faz [load] hidratar do SQLite e cada
/// mutação persistir em background — otimista, erro só logado (ver
/// `_persist`), nunca trava o app nem quebra a assinatura síncrona dos
/// métodos abaixo.
class ToyRepository extends ChangeNotifier {
  ToyRepository({ToyLocalService? localService})
      : _localService = localService,
        _toys = List.of(kInitialToys);

  final ToyLocalService? _localService;

  List<Toy> _toys;
  List<Toy> get toys => List.unmodifiable(_toys);

  bool _disposed = false;

  /// Hidrata do banco local. Sem [_localService] (a maioria dos testes),
  /// não faz nada — o catálogo fica no default síncrono do construtor
  /// (`kInitialToys`), igual sempre foi. Com [_localService]: se a tabela
  /// já tem dado (execuções anteriores), usa ele; se está vazia (primeira
  /// execução real do app), mantém `kInitialToys` e persiste essa seed uma
  /// única vez.
  Future<void> load() async {
    final service = _localService;
    if (service == null) return;
    final loaded = await service.loadAll();
    if (_disposed) return;
    if (loaded.isEmpty) {
      for (final toy in _toys) {
        unawaited(_persist(toy));
      }
    } else {
      _toys = loaded;
    }
    notifyListeners();
  }

  /// Creates and adds a new custom toy — same id scheme `AppState.addToy`
  /// always used (`custom_` + a microsecond timestamp), which never
  /// collides with a seed toy's id.
  Toy addNew({
    required String name,
    required double price,
    required int blockMin,
    required ToyInk ink,
    required String imageKey,
    required ToyCategory category,
    int qty = 1,
  }) {
    final toy = Toy(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      qty: qty,
      blockMin: blockMin,
      price: price,
      ink: ink,
      imageKey: imageKey,
      category: category,
    );
    _toys = [..._toys, toy];
    notifyListeners();
    unawaited(_persist(toy));
    return toy;
  }

  void updatePrice(String id, double price) {
    _toys = _toys.map((t) => t.id == id ? t.copyWith(price: price) : t).toList();
    notifyListeners();
    unawaited(_persist(_toys.firstWhere((t) => t.id == id)));
  }

  void updateBlockMinutes(String id, int blockMin) {
    _toys = _toys.map((t) => t.id == id ? t.copyWith(blockMin: blockMin) : t).toList();
    notifyListeners();
    unawaited(_persist(_toys.firstWhere((t) => t.id == id)));
  }

  /// Unconditional removal — the "refuse if it has rentals" guard needs
  /// `Rental` data this repository deliberately doesn't have, so it lives
  /// one layer up: `AppState.removeToy` (old world) and
  /// `ToyCatalogCubit.removeToy` (new world, spec
  /// 015-migracao-catalogo-grade) each hold their own `rentals` reference
  /// and apply the same check before calling this.
  void remove(String id) {
    _toys = _toys.where((t) => t.id != id).toList();
    notifyListeners();
    unawaited(_delete(id));
  }

  Future<void> _persist(Toy toy) async {
    final service = _localService;
    if (service == null) return;
    try {
      await service.upsert(toy);
    } catch (e) {
      debugPrint('ToyRepository: falha ao persistir brinquedo ${toy.id}: $e');
    }
  }

  Future<void> _delete(String id) async {
    final service = _localService;
    if (service == null) return;
    try {
      await service.delete(id);
    } catch (e) {
      debugPrint('ToyRepository: falha ao remover brinquedo $id: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
