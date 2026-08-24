import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/rental_repository.dart';
import '../../../../data/repositories/toy_repository.dart';
import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';
import '../../../../domain/use_cases/compute_toy_availability.dart';
import '../../../../theme/app_colors.dart' show ToyInk;
import 'toy_catalog_state.dart';

/// ViewModel for [AddToySheetView] (spec 012-migracao-catalogo-criacao)
/// and [CatalogView] (spec 015-migracao-catalogo-grade) — reads/writes
/// through the shared [ToyRepository] and (for availability) the shared
/// [RentalRepository], never touches `AppState`.
class ToyCatalogCubit extends Cubit<ToyCatalogState> {
  ToyCatalogCubit(
    ToyRepository toyRepository,
    RentalRepository rentalRepository, {
    ComputeToyAvailability computeToyAvailability = const ComputeToyAvailability(),
  })  : _toyRepository = toyRepository,
        _rentalRepository = rentalRepository,
        _computeToyAvailability = computeToyAvailability,
        super(_compute(toyRepository.toys, rentalRepository.rentals, computeToyAvailability)) {
    _toyRepository.addListener(_onRepositoriesChanged);
    _rentalRepository.addListener(_onRepositoriesChanged);
  }

  final ToyRepository _toyRepository;
  final RentalRepository _rentalRepository;
  final ComputeToyAvailability _computeToyAvailability;

  void _onRepositoriesChanged() =>
      emit(_compute(_toyRepository.toys, _rentalRepository.rentals, _computeToyAvailability));

  static ToyCatalogState _compute(List<Toy> toys, List<Rental> rentals, ComputeToyAvailability computeToyAvailability) {
    return ToyCatalogState(
      toys: toys,
      availability: {for (final t in toys) t.id: computeToyAvailability(t, rentals)},
    );
  }

  Toy addToy({
    required String name,
    required double price,
    required int blockMin,
    required ToyInk ink,
    required String imageKey,
    required ToyCategory category,
    int qty = 1,
  }) {
    return _toyRepository.addNew(
      name: name,
      price: price,
      blockMin: blockMin,
      ink: ink,
      imageKey: imageKey,
      category: category,
      qty: qty,
    );
  }

  void updatePrice(String id, double price) => _toyRepository.updatePrice(id, price);

  void updateBlockMinutes(String id, int blockMin) => _toyRepository.updateBlockMinutes(id, blockMin);

  /// Refuses (returns false) if any rental — active or in history —
  /// still references this toy, same guard `AppState.toyHasRentals` +
  /// `AppState.removeToy` always applied.
  bool removeToy(String id) {
    if (_rentalRepository.rentals.any((r) => r.toyId == id)) return false;
    _toyRepository.remove(id);
    return true;
  }

  @override
  Future<void> close() {
    _toyRepository.removeListener(_onRepositoriesChanged);
    _rentalRepository.removeListener(_onRepositoriesChanged);
    return super.close();
  }
}
