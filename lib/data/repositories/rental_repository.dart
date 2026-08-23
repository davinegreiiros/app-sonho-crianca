import 'package:flutter/foundation.dart';

import '../../domain/models/rental.dart';

/// Single source of truth for the toy-rental list (spec
/// 013-migracao-rental-repository-fundacao) — a foundation slice: only
/// structural ownership of `List<Rental>` moves here (adding a new rental,
/// removing a cancelled one). Everything else (creating/extending/ending a
/// rental, notification scheduling, report filters) still lives in
/// `AppState` until fatias 014-016 migrate their respective screens.
///
/// `Rental` is a mutable domain model by design (see
/// `lib/domain/models/rental.dart`) — mutating a field on a `Rental`
/// already in [rentals] (`AppState.extendActive`, `Rental.finish()` in
/// `confirmEnd`) needs no method here: it's the same object instance,
/// visible to every reader, whether or not this repository is involved.
///
/// Unlike `ToyRepository`/`BusinessSettingsRepository`, [rentals] is the
/// live, directly-mutable list itself — not `List.unmodifiable`. `AppState`
/// (and its tests) already relied on `rentals` being indexable/mutable in
/// place (e.g. replacing an element by index to backdate a `Rental`, since
/// `startedAt` is `final`); wrapping it read-only here would be a
/// behavior change this foundation slice explicitly isn't supposed to
/// make. [add]/[removeById] are still the intended way to change
/// membership — they're the only calls that notify listeners.
///
/// No `Service`/persistence layer: rentals aren't saved anywhere today
/// (same situation `ToyRepository` is in) — this seeds in memory, same as
/// `AppState._seed()` always did.
class RentalRepository extends ChangeNotifier {
  RentalRepository() : rentals = _seedInitial();

  final List<Rental> rentals;

  static List<Rental> _seedInitial() {
    DateTime minAgo(num n) => DateTime.now().subtract(Duration(seconds: (n * 60).round()));
    DateTime dAgo(num n) => DateTime.now().subtract(Duration(seconds: (n * 86400).round()));
    DateTime todayAt(int h) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final at = start.add(Duration(hours: h));
      final cap = now.subtract(const Duration(minutes: 5));
      return at.isBefore(cap) ? at : cap;
    }

    return [
      Rental(id: 'a1', toyId: 'carrinho', childName: 'Sofia', guardianName: 'Camila Ramos', guardianPhone: '(85) 98888-1010', startedAt: minAgo(9), durationMin: 15, price: 10, status: RentalStatus.active),
      Rental(id: 'a2', toyId: 'pula', childName: 'Enzo', guardianName: 'Marcos Lima', guardianPhone: '(85) 99999-2020', startedAt: minAgo(32), durationMin: 30, price: 12, status: RentalStatus.active),
      Rental(id: 'a3', toyId: 'patinete', childName: 'Lívia', guardianName: 'Ana Souza', guardianPhone: '(85) 98777-3030', startedAt: minAgo(3), durationMin: 15, price: 12, status: RentalStatus.active),
      Rental(id: 'h1', toyId: 'carrinho', childName: 'Davi', guardianName: 'Renata Alves', startedAt: todayAt(9).subtract(const Duration(minutes: 15)), durationMin: 15, price: 10, status: RentalStatus.done, endedAt: todayAt(9), paymentMethod: PaymentMethod.pix),
      Rental(id: 'h2', toyId: 'cama', childName: 'Manuela', guardianName: 'Bruno Costa', startedAt: todayAt(10).subtract(const Duration(minutes: 30)), durationMin: 30, price: 15, status: RentalStatus.done, endedAt: todayAt(10), paymentMethod: PaymentMethod.dinheiro),
      Rental(id: 'h3', toyId: 'piscina', childName: 'Théo', guardianName: 'Juliana Dias', startedAt: todayAt(11).subtract(const Duration(minutes: 20)), durationMin: 20, price: 10, status: RentalStatus.done, endedAt: todayAt(11), paymentMethod: PaymentMethod.cartao),
      Rental(id: 'h4', toyId: 'pula', childName: 'Alice', guardianName: 'Paulo Nunes', startedAt: dAgo(1), durationMin: 30, price: 24, status: RentalStatus.done, endedAt: dAgo(1).add(const Duration(minutes: 30)), paymentMethod: PaymentMethod.pix),
      Rental(id: 'h5', toyId: 'patinete', childName: 'Gabriel', guardianName: 'Carla Mota', startedAt: dAgo(1.2), durationMin: 15, price: 12, status: RentalStatus.done, endedAt: dAgo(1.2).add(const Duration(minutes: 15)), paymentMethod: PaymentMethod.dinheiro),
      Rental(id: 'h6', toyId: 'carrinho', childName: 'Isabela', guardianName: 'Fábio Reis', startedAt: dAgo(2), durationMin: 15, price: 10, status: RentalStatus.done, endedAt: dAgo(2).add(const Duration(minutes: 15)), paymentMethod: PaymentMethod.cartao),
      Rental(id: 'h7', toyId: 'cama', childName: 'Miguel', guardianName: 'Larissa Pinto', startedAt: dAgo(3.4), durationMin: 30, price: 15, status: RentalStatus.done, endedAt: dAgo(3.4).add(const Duration(minutes: 30)), paymentMethod: PaymentMethod.pix),
      Rental(id: 'h8', toyId: 'piscina', childName: 'Helena', guardianName: 'Diego Farias', startedAt: dAgo(5.5), durationMin: 20, price: 10, status: RentalStatus.done, endedAt: dAgo(5.5).add(const Duration(minutes: 20)), paymentMethod: PaymentMethod.pix),
    ];
  }

  void add(Rental rental) {
    rentals.add(rental);
    notifyListeners();
  }

  void removeById(String id) {
    rentals.removeWhere((r) => r.id == id);
    notifyListeners();
  }
}
