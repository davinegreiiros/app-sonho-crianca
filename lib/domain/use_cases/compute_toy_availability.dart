import '../models/rental.dart';
import '../models/toy.dart';

/// Cross-repository read: how many units of a [Toy] are free right now,
/// given the current [Rental] list. First Use Case in this codebase
/// (spec 015-migracao-catalogo-grade) — justified because it crosses
/// `Toy` and `Rental`, two different Repositories that deliberately don't
/// know about each other (decision from specs 012/013), and the formula
/// is likely reused when fatia 016 migrates the rental flow.
///
/// Same formula `AppState.toyAvailable` always used: total quantity minus
/// how many active rentals reference this toy.
class ComputeToyAvailability {
  const ComputeToyAvailability();

  int call(Toy toy, List<Rental> rentals) {
    final rented = rentals.where((r) => r.status == RentalStatus.active && r.toyId == toy.id).length;
    return toy.qty - rented;
  }
}
