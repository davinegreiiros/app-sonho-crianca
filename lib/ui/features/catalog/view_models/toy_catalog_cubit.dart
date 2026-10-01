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

  /// Busca o catálogo atual no backend (spec 025) — chamado pela `View` ao
  /// entrar na tela, não no boot do app (mesmo racional de
  /// `BusinessSettingsCubit.refresh`).
  Future<void> refreshCatalog() => _toyRepository.load();

  static ToyCatalogState _compute(List<Toy> toys, List<Rental> rentals, ComputeToyAvailability computeToyAvailability) {
    return ToyCatalogState(
      toys: toys,
      availability: {for (final t in toys) t.id: computeToyAvailability(t, rentals)},
    );
  }

  /// Cria o brinquedo no backend (spec 025) — deixa
  /// `ApiUnauthorizedException`/`ApiNetworkException`/`ApiException` subir
  /// pra View decidir a mensagem (mesmo padrão de `LoginCubit`/
  /// `BusinessSettingsCubit`).
  Future<Toy> addToy({
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

  Future<void> updatePrice(String id, double price) => _toyRepository.updatePrice(id, price);

  Future<void> updateBlockMinutes(String id, int blockMin) => _toyRepository.updateBlockMinutes(id, blockMin);

  /// Recusa local (devolve `false`) se alguma locação — ativa ou histórico
  /// — ainda referencia este brinquedo, antes de gastar uma chamada de
  /// rede; o backend aplica a mesma regra de verdade (spec 001, cenário 6,
  /// 409) caso o dado local esteja desatualizado.
  Future<bool> removeToy(String id) async {
    if (_rentalRepository.rentals.any((r) => r.toyId == id)) return false;
    await _toyRepository.remove(id);
    return true;
  }

  @override
  Future<void> close() {
    _toyRepository.removeListener(_onRepositoriesChanged);
    _rentalRepository.removeListener(_onRepositoriesChanged);
    return super.close();
  }
}
