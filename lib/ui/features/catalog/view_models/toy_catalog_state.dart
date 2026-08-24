import 'package:equatable/equatable.dart';

import '../../../../domain/models/toy.dart';

/// State emitted by [ToyCatalogCubit] — the current toy list plus (since
/// spec 015-migracao-catalogo-grade) how many units of each are free
/// right now, for `CatalogView`'s availability tickets.
class ToyCatalogState extends Equatable {
  const ToyCatalogState({required this.toys, required this.availability});

  final List<Toy> toys;

  /// toyId -> units currently free, from [ComputeToyAvailability].
  final Map<String, int> availability;

  /// Falls back to the toy's full `qty` if it's somehow missing from
  /// [availability] (shouldn't happen — every toy in [toys] gets an
  /// entry — but matches the safety-net style `AppState.toyById` used).
  int availabilityOf(Toy toy) => availability[toy.id] ?? toy.qty;

  @override
  List<Object?> get props => [toys, availability];
}
