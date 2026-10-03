// Widget tests for spec 008 (adicionar tempo e alarme visual): the "+
// tempo" chips only show on a fixed-duration active card, and the overtime
// alarm icon only shows once a fixed-duration rental has run past its
// duration.
//
// Migrado na spec 026-rental-via-backend: `AppState.submitNew` foi
// removido — cria a locação via `NewRentalCubit` direto (mesmo Cubit que
// a UI usa desde a spec 017); injeta `toyRepository`/`rentalRepository`/
// `authRepository` fakes (sem isso, cairia no backend real assim que a
// locação fosse criada).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/data/services/rental_remote_service.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/test_keys.dart';
import 'package:sonho_de_crianca/ui/features/rental/view_models/new_rental_cubit.dart';

import 'fakes/fake_business_settings.dart';
import 'fakes/fake_rental_backend.dart';
import 'fakes/fake_toy_backend.dart';

Future<AppState> _pumpApp(WidgetTester tester) async {
  final authRepository = fakeLoggedInAuthRepository();
  await tester.pumpWidget(SonhoDeCriancaApp(
    authRepository: authRepository,
    toyRepository: fakeToyRepository(initial: kInitialToys, authRepository: authRepository),
    rentalRepository: RentalRepository(
      service: RentalRemoteService(ApiClient(httpClient: fakeRentalBackend())),
      authRepository: authRepository,
    ),
    startInPostoAdminMode: true,
  ));
  await tester.pump(const Duration(milliseconds: 400));
  return Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);
}

NewRentalCubit _newRentalCubit(WidgetTester tester) =>
    BlocProvider.of<NewRentalCubit>(tester.element(find.byType(MaterialApp)), listen: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('"+ tempo" chips show on a fixed-duration card and extend it on tap', (tester) async {
    final state = await _pumpApp(tester);
    final newRentalCubit = _newRentalCubit(tester);

    newRentalCubit.setToy('cama'); // blockMin 30, price 15 -> 0.50/min
    newRentalCubit.setChildName('Fixo Extend');
    newRentalCubit.applyDuration(15); // price = round(15 * 15/30) = 8
    final rental = await newRentalCubit.submit();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(TestKeys.navActive));
    await tester.pump(const Duration(milliseconds: 400));

    final chip = find.byKey(TestKeys.extendRentalButton(rental.id, 10));
    await tester.scrollUntilVisible(chip, 200, scrollable: find.byType(Scrollable).first);

    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 400));

    final extended = state.rentals.firstWhere((r) => r.id == rental.id);
    expect(extended.durationMin, 25);
    expect(extended.price, 13); // 8 + 0.50/min * 10min
  });

  testWidgets('"+ tempo" chips are absent on a tempo corrido (open-ended) card', (tester) async {
    await _pumpApp(tester);
    final newRentalCubit = _newRentalCubit(tester);

    newRentalCubit.setToy('cama');
    newRentalCubit.setChildName('Aberta Extend');
    newRentalCubit.setOpenEnded(true);
    final rental = await newRentalCubit.submit();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(TestKeys.navActive));
    await tester.pump(const Duration(milliseconds: 400));

    final card = find.byKey(TestKeys.activeCardKey(rental.id));
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(TestKeys.extendRentalButton(rental.id, 10)), findsNothing);
  });

  testWidgets('overtime freezes the clock at 00:00 and shows "TEMPO ESGOTADO" once a fixed-duration rental runs past its time', (
    tester,
  ) async {
    final state = await _pumpApp(tester);
    final newRentalCubit = _newRentalCubit(tester);

    newRentalCubit.setToy('cama');
    newRentalCubit.setChildName('Estourada');
    newRentalCubit.applyDuration(10);
    final rental = await newRentalCubit.submit();
    await tester.pump(const Duration(milliseconds: 400));

    // Not yet overtime.
    await tester.tap(find.byKey(TestKeys.navActive));
    await tester.pump(const Duration(milliseconds: 400));
    final card = find.byKey(TestKeys.activeCardKey(rental.id));
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    expect(card, findsOneWidget);
    // Scoped to this card — the seeded data has another rental already in
    // overtime, so an unscoped `find.text` would false-positive on it.
    final alarmLabel = find.descendant(of: card, matching: find.text('TEMPO ESGOTADO'));
    expect(alarmLabel, findsNothing);

    // Back-date the start past the 10min duration.
    final index = state.rentals.indexWhere((r) => r.id == rental.id);
    state.rentals[index] = Rental(
      id: rental.id,
      toyId: rental.toyId,
      childName: rental.childName,
      guardianName: rental.guardianName,
      startedAt: DateTime.now().subtract(const Duration(minutes: 12)),
      durationMin: 10,
      price: rental.price,
      status: RentalStatus.active,
    );
    // ActiveTabView (spec 018) rebuilds off ActiveRentalsCubit's own 1s
    // ticker, not AppState's notifyListeners — pump past that instead of
    // the old "state.setTab(state.tab)" no-op-notify trick.
    await tester.pump(const Duration(milliseconds: 1100));

    expect(alarmLabel, findsOneWidget);
    // Clock freezes at 00:00 instead of counting up past the duration.
    expect(find.descendant(of: card, matching: find.text('00:00')), findsOneWidget);
  });
}
