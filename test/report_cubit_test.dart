// Tests for spec 014 (migração — relatório): the new Cubit is testable
// without a WidgetTester, replicates AppState's old period-filter/
// breakdown formulas, and reacts to RentalRepository/ToyRepository
// changes made elsewhere (e.g. by AppState, the old world).

import 'package:flutter_test/flutter_test.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/repositories/toy_repository.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/ui/features/report/view_models/report_cubit.dart';
import 'package:sonho_de_crianca/ui/features/report/view_models/report_state.dart';

void main() {
  group('ReportCubit', () {
    test('defaults to "today" and only counts rentals finished today', () {
      final rentalRepository = RentalRepository.withDemoSeed();
      final cubit = ReportCubit(rentalRepository, ToyRepository());

      // Seed: h1/h2/h3 finished "today" (todayAt helper), h4-h8 finished
      // 1+ days ago — only h1/h2/h3 should count for the default period.
      expect(cubit.state.period, ReportPeriod.today);
      expect(cubit.state.filteredCount, 3);
      expect(cubit.state.total, 10 + 15 + 10); // h1 + h2 + h3 prices

      cubit.close();
    });

    test('setPeriod(all) includes every finished rental, none of the active ones', () {
      final rentalRepository = RentalRepository.withDemoSeed();
      final cubit = ReportCubit(rentalRepository, ToyRepository());

      cubit.setPeriod(ReportPeriod.all);

      expect(cubit.state.period, ReportPeriod.all);
      expect(cubit.state.filteredCount, 8); // h1-h8, not a1-a3 (still active)
      expect(cubit.state.historyList, hasLength(8));
      expect(cubit.state.historyList.every((r) => r.status == RentalStatus.done), isTrue);

      cubit.close();
    });

    test('paymentBreakdown sums by method, toyBreakdown sums by toy, both over the filtered set', () {
      final rentalRepository = RentalRepository();
      final cubit = ReportCubit(rentalRepository, ToyRepository());
      cubit.setPeriod(ReportPeriod.all);

      final byMethod = cubit.state.paymentBreakdown;
      final total = byMethod.values.fold(0.0, (a, v) => a + v);
      expect(total, cubit.state.total);

      final byToy = cubit.state.toyBreakdown;
      final toyTotal = byToy.fold(0.0, (a, e) => a + e.total);
      expect(toyTotal, cubit.state.total);
      // Sorted descending by total.
      for (var i = 1; i < byToy.length; i++) {
        expect(byToy[i - 1].total, greaterThanOrEqualTo(byToy[i].total));
      }

      cubit.close();
    });

    test('reacts when RentalRepository changes elsewhere (shared instance)', () {
      final rentalRepository = RentalRepository();
      final toyRepository = ToyRepository();
      final cubit = ReportCubit(rentalRepository, toyRepository);
      cubit.setPeriod(ReportPeriod.all);
      final before = cubit.state.filteredCount;

      // Simulates AppState.cancelActive / another finished rental — this
      // repository instance is the one AppState itself would share.
      rentalRepository.add(Rental(
        id: 'r-report-test',
        toyId: 'carrinho',
        childName: 'Teste Relatório',
        guardianName: 'Responsável Teste',
        startedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        durationMin: 15,
        price: 10,
        status: RentalStatus.done,
        endedAt: DateTime.now(),
        paymentMethod: PaymentMethod.pix,
      ));

      expect(cubit.state.filteredCount, before + 1);

      cubit.close();
    });
  });
}
