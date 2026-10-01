// Tests for spec 006 (locação em tempo corrido): price calculation and the
// create/finish/cancel flow for a rental with no fixed duration.
//
// Migrado na spec 026-rental-via-backend: `AppState.submitNew`/
// `confirmEnd`/`cancelActive` foram removidos — os testes que criam/
// encerram/cancelam locação agora injetam `toyRepository`/
// `rentalRepository`/`authRepository` fakes e acionam `NewRentalCubit`/
// `ActiveRentalsCubit` direto (mesmos Cubits que a UI usa desde as specs
// 017/018). `AppState.computeFinalPrice` (puro, sem rede) continua igual.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/data/services/rental_remote_service.dart';
import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/test_keys.dart';
import 'package:sonho_de_crianca/ui/features/rental/view_models/active_rentals_cubit.dart';
import 'package:sonho_de_crianca/ui/features/rental/view_models/new_rental_cubit.dart';

import 'fakes/fake_business_settings.dart';
import 'fakes/fake_rental_backend.dart';
import 'fakes/fake_toy_backend.dart';

/// Devolve o `RentalRepository` junto do `AppState` — testes que
/// "retroagem" o `startedAt` de uma locação via mutação direta por
/// índice (`rentals[index] = ...`) precisam chamar `notifyListeners()`
/// nele depois: `ActiveRentalsCubit` guarda seu próprio snapshot de
/// `activeRentals`, atualizado só quando o Repository notifica (ou pelo
/// ticker de 1s da tela de Ativas) — `AppState.notifyListeners()` não
/// alcança o Cubit, que escuta o Repository, não o AppState.
Future<(AppState, RentalRepository)> _pumpApp(WidgetTester tester) async {
  final authRepository = fakeLoggedInAuthRepository();
  final rentalRepository = RentalRepository(
    service: RentalRemoteService(ApiClient(httpClient: fakeRentalBackend())),
    authRepository: authRepository,
  );
  await tester.pumpWidget(SonhoDeCriancaApp(
    authRepository: authRepository,
    toyRepository: fakeToyRepository(initial: kInitialToys, authRepository: authRepository),
    rentalRepository: rentalRepository,
    startInPostoAdminMode: true,
  ));
  await tester.pump(const Duration(milliseconds: 400));
  return (Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false), rentalRepository);
}

NewRentalCubit _newRentalCubit(WidgetTester tester) =>
    BlocProvider.of<NewRentalCubit>(tester.element(find.byType(MaterialApp)), listen: false);

ActiveRentalsCubit _activeRentalsCubit(WidgetTester tester) =>
    BlocProvider.of<ActiveRentalsCubit>(tester.element(find.byType(MaterialApp)), listen: false);

void main() {
  // AppState() kicks off an un-awaited SharedPreferences.getInstance() call
  // (business Pix settings, spec 004) — without this, that hits a real
  // platform channel with no test binding registered and throws async,
  // which flutter_test then blames on whatever test happens to be running.
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('AppState.computeFinalPrice', () {
    test('22 minutes on a R\$0,50/min toy (Cama Elástica) charges R\$11,00', () {
      final state = AppState();
      final camaElastica = state.toyById('cama'); // blockMin 30, price 15 -> 0.50/min
      expect(state.ratePerMinute(camaElastica), 0.5);

      final rental = Rental(
        id: 'x1',
        toyId: 'cama',
        childName: 'Teste',
        guardianName: '—',
        startedAt: DateTime.now().subtract(const Duration(minutes: 22)),
        durationMin: null, // open-ended
        price: 0,
        status: RentalStatus.active,
      );

      expect(state.computeFinalPrice(rental), 11.0);
      state.dispose();
    });

    test('a non-trivial fraction (22min37s) rounds only the final price to the cent', () {
      final state = AppState();
      final rental = Rental(
        id: 'x2',
        toyId: 'cama', // 0.50/min
        childName: 'Teste',
        guardianName: '—',
        startedAt: DateTime.now().subtract(const Duration(minutes: 22, seconds: 37)),
        durationMin: null,
        price: 0,
        status: RentalStatus.active,
      );

      // 22 + 37/60 = 22.6166...min * 0.5 = 11.3083... -> rounds to 11.31.
      expect(state.computeFinalPrice(rental), 11.31);
      state.dispose();
    });

    test('a fixed-duration rental is untouched — returns its own price as-is', () {
      final state = AppState();
      final rental = Rental(
        id: 'x3',
        toyId: 'cama',
        childName: 'Teste',
        guardianName: '—',
        startedAt: DateTime.now().subtract(const Duration(minutes: 99)),
        durationMin: 30,
        price: 15,
        status: RentalStatus.active,
      );

      expect(state.computeFinalPrice(rental), 15);
      state.dispose();
    });
  });

  group('customizable tempo-corrido rate', () {
    testWidgets('a custom rate overrides the catalog-derived one and is what actually charges', (tester) async {
      final (state, _) = await _pumpApp(tester);
      final newRentalCubit = _newRentalCubit(tester);

      newRentalCubit.setToy('cama'); // catalog-derived: 0.50/min
      newRentalCubit.setChildName('Taxa Custom');
      newRentalCubit.setOpenEnded(true);
      newRentalCubit.setCustomRate(1.20); // operator overrides
      final rental = await newRentalCubit.submit();

      expect(rental.ratePerMinute, 1.20);

      final index = state.rentals.indexWhere((r) => r.id == rental.id);
      state.rentals[index] = Rental(
        id: rental.id,
        toyId: rental.toyId,
        childName: rental.childName,
        guardianName: rental.guardianName,
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        durationMin: null,
        price: 0,
        status: RentalStatus.active,
        ratePerMinute: rental.ratePerMinute,
      );

      // 10min at R$1,20/min — not the R$0,50/min the catalog would suggest.
      expect(state.computeFinalPrice(state.rentals.firstWhere((r) => r.id == rental.id)), 12.0);
    });

    testWidgets('without an override, the rate still falls back to the catalog default', (tester) async {
      await _pumpApp(tester);
      final newRentalCubit = _newRentalCubit(tester);

      newRentalCubit.setToy('cama'); // 0.50/min
      newRentalCubit.setChildName('Taxa Padrao');
      newRentalCubit.setOpenEnded(true);
      final rental = await newRentalCubit.submit();

      expect(rental.ratePerMinute, 0.5);
    });

    testWidgets('switching the toy clears a previously typed custom rate', (tester) async {
      await _pumpApp(tester);
      final newRentalCubit = _newRentalCubit(tester);

      newRentalCubit.setToy('cama');
      newRentalCubit.setCustomRate(9.99);
      expect(newRentalCubit.state.customRatePerMinute, 9.99);

      newRentalCubit.setToy('pula');
      expect(newRentalCubit.state.customRatePerMinute, isNull);
    });
  });

  group('open-ended rental flow', () {
    testWidgets('creating, then finishing, an open-ended rental charges the computed price', (tester) async {
      final (state, rentalRepository) = await _pumpApp(tester);
      final newRentalCubit = _newRentalCubit(tester);
      final activeRentalsCubit = _activeRentalsCubit(tester);

      newRentalCubit.setToy('cama'); // 0.50/min
      newRentalCubit.setChildName('Aberta');
      newRentalCubit.setOpenEnded(true);
      final rental = await newRentalCubit.submit();

      expect(rental.isOpenEnded, isTrue);
      expect(rental.durationMin, isNull);
      expect(rental.price, 0); // placeholder until finished

      // Back-date the start so there's a deterministic elapsed time to
      // charge for, instead of asserting against a near-zero duration.
      final backdated = Rental(
        id: rental.id,
        toyId: rental.toyId,
        childName: rental.childName,
        guardianName: rental.guardianName,
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        durationMin: null,
        price: 0,
        status: RentalStatus.active,
      );
      final index = state.rentals.indexWhere((r) => r.id == rental.id);
      state.rentals[index] = backdated;
      rentalRepository.notifyListeners(); // ActiveRentalsCubit só vê a troca se notificado

      activeRentalsCubit.openEnd(rental.id);
      activeRentalsCubit.selectPayment(PaymentMethod.pix);
      await activeRentalsCubit.confirmEnd();

      final finished = state.rentals.firstWhere((r) => r.id == rental.id);
      expect(finished.status, RentalStatus.done);
      expect(finished.price, 5.0); // 10min * 0.50/min
    });

    testWidgets('Pix QR freezes the price — a slow-to-pay customer is not charged more', (tester) async {
      final (state, rentalRepository) = await _pumpApp(tester);
      final newRentalCubit = _newRentalCubit(tester);
      final activeRentalsCubit = _activeRentalsCubit(tester);

      newRentalCubit.setToy('cama'); // 0.50/min
      newRentalCubit.setChildName('Aberta Pix');
      newRentalCubit.setOpenEnded(true);
      final rental = await newRentalCubit.submit();

      // 10 min elapsed at the moment the operator opens the Pix QR.
      void backdateStart(Duration elapsed) {
        final index = state.rentals.indexWhere((r) => r.id == rental.id);
        state.rentals[index] = Rental(
          id: rental.id,
          toyId: rental.toyId,
          childName: rental.childName,
          guardianName: rental.guardianName,
          startedAt: DateTime.now().subtract(elapsed),
          durationMin: null,
          price: 0,
          status: RentalStatus.active,
        );
        rentalRepository.notifyListeners(); // ActiveRentalsCubit só vê a troca se notificado
      }

      backdateStart(const Duration(minutes: 10));
      activeRentalsCubit.openEnd(rental.id);
      activeRentalsCubit.selectPayment(PaymentMethod.pix);
      activeRentalsCubit.showPixQrStep(); // freezes the price at the 10min mark: R$5,00
      expect(activeRentalsCubit.state.endFrozenPrice, 5.0);

      // The customer takes a while to actually scan/pay — the clock the
      // active-rental card would show keeps climbing underneath the QR.
      backdateStart(const Duration(minutes: 16));
      expect(activeRentalsCubit.computeFinalPrice(state.rentals.firstWhere((r) => r.id == rental.id)), 8.0);

      await activeRentalsCubit.confirmEnd();

      final finished = state.rentals.firstWhere((r) => r.id == rental.id);
      // Charged the amount actually encoded in the QR the customer
      // scanned (R$5,00) — not the inflated R$8,00 the delay would have
      // produced if `confirmEnd` had recomputed it fresh.
      expect(finished.price, 5.0);
    });

    testWidgets('cancelling an open-ended rental charges nothing', (tester) async {
      final (state, _) = await _pumpApp(tester);
      final newRentalCubit = _newRentalCubit(tester);
      final activeRentalsCubit = _activeRentalsCubit(tester);

      newRentalCubit.setToy('cama');
      newRentalCubit.setChildName('Cancelada');
      newRentalCubit.setOpenEnded(true);
      final rental = await newRentalCubit.submit();

      await activeRentalsCubit.cancelActive(rental.id);

      // spec 026: cancelar marca `done` sem pagamento, não remove.
      final canceled = state.rentals.firstWhere((r) => r.id == rental.id);
      expect(canceled.status, RentalStatus.done);
      expect(canceled.paymentMethod, isNull);
      expect(canceled.price, 0); // nunca chegou a cobrar nada
    });

    testWidgets('"Nova locação" sheet toggles to tempo corrido and hides duration/price fields', (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.byKey(TestKeys.fabNewRental));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('10min'), findsOneWidget); // fixed-duration presets shown by default

      // The sheet's own SingleChildScrollView shrink-wraps its content, so
      // `ensureVisible`/`scrollUntilVisible` (which compare against that
      // scrollable's own viewport) think everything is already visible
      // even when it's below the actual screen bounds — drag it manually.
      await tester.drag(find.byKey(TestKeys.draftChildNameField), const Offset(0, -300), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(TestKeys.rentalModeOpenEnded));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('10min'), findsNothing); // presets hidden in tempo corrido
      expect(find.textContaining('/min'), findsOneWidget);
    });
  });
}
