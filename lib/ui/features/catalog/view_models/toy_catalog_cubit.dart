import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/toy_repository.dart';
import '../../../../domain/models/toy.dart';
import '../../../../theme/app_colors.dart' show ToyInk;
import 'toy_catalog_state.dart';

/// ViewModel for [AddToySheetView] (spec 012-migracao-catalogo-criacao) —
/// reads/writes through the shared [ToyRepository], never touches
/// `AppState`.
class ToyCatalogCubit extends Cubit<ToyCatalogState> {
  ToyCatalogCubit(this._repository) : super(ToyCatalogState(toys: _repository.toys)) {
    _repository.addListener(_onRepositoryChanged);
  }

  final ToyRepository _repository;

  void _onRepositoryChanged() => emit(ToyCatalogState(toys: _repository.toys));

  Toy addToy({
    required String name,
    required double price,
    required int blockMin,
    required ToyInk ink,
    required String imageKey,
    required ToyCategory category,
    int qty = 1,
  }) {
    return _repository.addNew(
      name: name,
      price: price,
      blockMin: blockMin,
      ink: ink,
      imageKey: imageKey,
      category: category,
      qty: qty,
    );
  }

  @override
  Future<void> close() {
    _repository.removeListener(_onRepositoryChanged);
    return super.close();
  }
}
