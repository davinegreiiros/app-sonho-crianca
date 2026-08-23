import 'package:equatable/equatable.dart';

import '../../../../domain/models/toy.dart';

/// State emitted by [ToyCatalogCubit] — a thin envelope around the
/// current toy list. Kept here (not just consumed inline by
/// `AddToySheetView`, which doesn't need it) so fatia 014 can reuse this
/// same Cubit for `catalog_tab.dart`'s grid without redesigning it.
class ToyCatalogState extends Equatable {
  const ToyCatalogState({required this.toys});

  final List<Toy> toys;

  @override
  List<Object?> get props => [toys];
}
