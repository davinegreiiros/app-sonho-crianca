import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';

import '../../domain/models/rental.dart';
import '../services/rental_local_service.dart';

/// Single source of truth for the toy-rental list (spec
/// 013-migracao-rental-repository-fundacao).
///
/// `Rental` is a mutable domain model by design (see
/// `lib/domain/models/rental.dart`) — mutating a field on a `Rental`
/// already in [rentals] needs no method here: it's the same object
/// instance, visible to every reader, whether or not this repository is
/// involved.
///
/// [rentals] is the live, directly-mutable list itself — not
/// `List.unmodifiable`. `AppState` (e outros testes) já dependem de
/// `rentals` ser indexável/mutável em lugar (ex.: substituir um elemento
/// por índice pra "voltar no tempo" um `Rental`, já que `startedAt` é
/// `final`). Por isso [load] nunca reatribui [rentals] (é `final`) — só
/// limpa e repopula em lugar.
///
/// Persistência (spec 020-persistencia-local): [_localService], quando
/// injetado (sempre em `main.dart`; `null` na maioria dos testes), faz
/// [load] hidratar do SQLite e cada mutação persistir em background —
/// mesmo padrão otimista de `ToyRepository`. O construtor default começa
/// **vazio**: o app real nunca semeia locação fictícia, só o catálogo tem
/// seed inicial. [withDemoSeed] existe só pra teste, ver doc no construtor.
class RentalRepository extends ChangeNotifier {
  RentalRepository({RentalLocalService? localService})
      : rentals = [],
        _localService = localService;

  /// Mesma lista de 11 locações de demonstração (`a1`-`a3` ativas,
  /// `h1`-`h8` finalizadas) que `RentalRepository()` sempre semeou antes da
  /// spec 020 — vários testes dependem implicitamente desses dados. O app
  /// real nunca usa este construtor: `main.dart` usa `RentalRepository()`
  /// (vazio) + `load()`.
  RentalRepository.withDemoSeed({RentalLocalService? localService})
      : rentals = _seedInitial(),
        _localService = localService;

  final List<Rental> rentals;
  final RentalLocalService? _localService;

  bool _disposed = false;

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

  /// Hidrata do banco local. Sem [_localService] (a maioria dos testes),
  /// não faz nada — [rentals] fica no default do construtor usado (`[]` ou
  /// a seed de demonstração). Com [_localService]: substitui o conteúdo de
  /// [rentals] pelo que está persistido (vazio na primeira execução real —
  /// sem seed de demonstração, ver classe acima).
  Future<void> load() async {
    final service = _localService;
    if (service == null) return;
    final loaded = await service.loadAll();
    if (_disposed) return;
    rentals
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }

  /// Builds a new active `Rental` (same id scheme `AppState.submitNew`
  /// always used — a microsecond timestamp — spec
  /// 017-migracao-nova-locacao) and adds it. `startedAt` is always "now"
  /// — a rental starts the moment it's created.
  Rental addNew({
    required String toyId,
    required String childName,
    required String guardianName,
    required String guardianPhone,
    required int? durationMin,
    required double price,
    required double? ratePerMinute,
  }) {
    final rental = Rental(
      id: 'r${DateTime.now().microsecondsSinceEpoch}',
      toyId: toyId,
      childName: childName,
      guardianName: guardianName,
      guardianPhone: guardianPhone,
      startedAt: DateTime.now(),
      durationMin: durationMin,
      price: price,
      status: RentalStatus.active,
      ratePerMinute: ratePerMinute,
    );
    add(rental);
    return rental;
  }

  void add(Rental rental) {
    rentals.add(rental);
    notifyListeners();
    unawaited(_persist(rental));
  }

  void removeById(String id) {
    rentals.removeWhere((r) => r.id == id);
    notifyListeners();
    unawaited(_delete(id));
  }

  /// Adds `addMinutes`-worth of duration/price to an active fixed-duration
  /// rental (the caller computes the new values — the rate/minute formula
  /// needs `Toy` data this repository deliberately doesn't have) and
  /// notifies. Spec 018-migracao-locacao-ativa-encerrar: before this,
  /// `AppState.extendActive` mutated the `Rental` in place without ever
  /// calling this repository's `notifyListeners()`, so `ReportCubit`/
  /// `ToyCatalogCubit` (which only listen here) never found out a rental
  /// had been extended — this method is the fix, used by both worlds.
  void extend(String rentalId, {required int durationMin, required double price}) {
    final r = rentals.firstWhere((r) => r.id == rentalId, orElse: () => rentals.first);
    r.durationMin = durationMin;
    r.price = price;
    notifyListeners();
    unawaited(_persist(r));
  }

  /// Marks a rental done and notifies — same "AppState mutated without
  /// notifying this repository" gap [extend] fixes, now for `confirmEnd`.
  /// [finalPrice] is only passed for an open-ended rental (the caller —
  /// `AppState`/`ActiveRentalsCubit` — decides; a fixed-duration rental's
  /// price never changes at finish time).
  void finish(String rentalId, PaymentMethod method, {double? finalPrice}) {
    final r = rentals.firstWhere((r) => r.id == rentalId, orElse: () => rentals.first);
    if (finalPrice != null) r.price = finalPrice;
    r.finish(method);
    notifyListeners();
    unawaited(_persist(r));
  }

  Future<void> _persist(Rental rental) async {
    final service = _localService;
    if (service == null) return;
    try {
      await service.upsert(rental);
    } catch (e) {
      debugPrint('RentalRepository: falha ao persistir locação ${rental.id}: $e');
    }
  }

  Future<void> _delete(String id) async {
    final service = _localService;
    if (service == null) return;
    try {
      await service.delete(id);
    } catch (e) {
      debugPrint('RentalRepository: falha ao remover locação $id: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
