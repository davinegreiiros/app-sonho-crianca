import 'package:flutter/foundation.dart';

import '../../domain/models/toy.dart';
import '../../theme/app_colors.dart' show ToyInk;

/// Single source of truth for the toy catalog (spec
/// 012-migracao-catalogo-criacao) — one shared instance (wired in
/// `main.dart`) consumed both by `ToyCatalogCubit` (new world,
/// `lib/ui/features/catalog/`) and by `AppState.toys`/`toyById`/etc. (old
/// world, kept as a thin proxy until `catalog_tab.dart` migrates in fatia
/// 014 — see the "Aprendizado da fatia 012" note in
/// `specs/010-migracao-arquitetura-camadas/spec.md`).
///
/// No `Service`/persistence layer: toys aren't saved anywhere today (they
/// reseed from `kInitialToys` every boot, same as before this spec) — an
/// empty Service wrapping nothing would be over-engineering.
class ToyRepository extends ChangeNotifier {
  ToyRepository() : _toys = List.of(kInitialToys);

  List<Toy> _toys;
  List<Toy> get toys => List.unmodifiable(_toys);

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
    return toy;
  }

  void updatePrice(String id, double price) {
    _toys = _toys.map((t) => t.id == id ? t.copyWith(price: price) : t).toList();
    notifyListeners();
  }

  void updateBlockMinutes(String id, int blockMin) {
    _toys = _toys.map((t) => t.id == id ? t.copyWith(blockMin: blockMin) : t).toList();
    notifyListeners();
  }

  /// Unconditional removal — the "refuse if it has rentals" guard needs
  /// `Rental` data this repository doesn't have, so it stays in
  /// `AppState.removeToy` (which already holds `rentals`) until fatia 014.
  void remove(String id) {
    _toys = _toys.where((t) => t.id != id).toList();
    notifyListeners();
  }
}
