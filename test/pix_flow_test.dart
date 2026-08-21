// Tests for spec 004 (QR Code Pix): the "Finalizar locação" branch by
// payment method — Pix without config opens settings, Pix with config
// shows the QR and only finishes on "Concluir", Cartão/Dinheiro unchanged.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/test_keys.dart';

Future<AppState> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const SonhoDeCriancaApp());
  await tester.pump(const Duration(milliseconds: 400));
  return Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);
}

/// `EndRentalDialog`'s pop-in (`Curves.easeOutBack` scale) only actually
/// lays out its final size after several small frames — a single big
/// `pump(duration)` leaves its content at a collapsed zero-size rect even
/// well past the transition's nominal duration. Several small pumps (as a
/// real device's frame scheduler would deliver) converge reliably. Can't
/// use `pumpAndSettle` here: the FAB/header/timer animations elsewhere in
/// the tree repeat forever and would hang it.
Future<void> _settle(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  SharedPreferences.setMockInitialValues({});

  testWidgets('Cartão still finishes the rental immediately, unchanged', (tester) async {
    final state = await _pumpApp(tester);
    final rental = state.activeRentals.first;

    await tester.tap(find.byKey(TestKeys.navActive));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(TestKeys.finishRentalButton(rental.id)));
    await tester.pump();
    await tester.tap(find.byKey(TestKeys.finishRentalButton(rental.id)));
    await _settle(tester);

    await tester.tap(find.byKey(TestKeys.paymentOption('cartao')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(TestKeys.confirmEndButton));
    await _settle(tester);

    expect(state.rentals.firstWhere((r) => r.id == rental.id).status.name, 'done');
    expect(find.byKey(TestKeys.pixQrImage), findsNothing);
  });

  testWidgets('Pix without business settings configured opens settings instead of finishing', (tester) async {
    final state = await _pumpApp(tester);
    final rental = state.activeRentals.first;

    await tester.tap(find.byKey(TestKeys.navActive));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(TestKeys.finishRentalButton(rental.id)));
    await tester.pump();
    await tester.tap(find.byKey(TestKeys.finishRentalButton(rental.id)));
    await _settle(tester);

    await tester.tap(find.byKey(TestKeys.paymentOption('pix')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(TestKeys.confirmEndButton));
    await _settle(tester);

    // Not finished — sent to the business settings sheet instead.
    expect(state.rentals.firstWhere((r) => r.id == rental.id).status.name, 'active');
    expect(find.byKey(TestKeys.businessNameField), findsOneWidget);
    expect(find.textContaining('Configure isso antes de cobrar por Pix'), findsOneWidget);
  });

  testWidgets('Pix with business settings configured shows the QR, only finishes on "Concluir"', (tester) async {
    final state = await _pumpApp(tester);
    await state.updateBusinessSettings(merchantName: 'Sonho de Criança', merchantCity: 'Fortaleza', pixKey: '85999998888');
    final rental = state.activeRentals.first;

    await tester.tap(find.byKey(TestKeys.navActive));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byKey(TestKeys.finishRentalButton(rental.id)));
    await tester.pump();
    await tester.tap(find.byKey(TestKeys.finishRentalButton(rental.id)));
    await _settle(tester);

    await tester.tap(find.byKey(TestKeys.paymentOption('pix')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(TestKeys.confirmEndButton));
    await _settle(tester);

    // QR step showing, rental not finished yet.
    expect(find.byKey(TestKeys.pixQrImage), findsOneWidget);
    expect(state.rentals.firstWhere((r) => r.id == rental.id).status.name, 'active');

    await tester.tap(find.byKey(TestKeys.pixQrDoneButton));
    await _settle(tester);

    final finished = state.rentals.firstWhere((r) => r.id == rental.id);
    expect(finished.status.name, 'done');
    expect(finished.paymentMethod?.name, 'pix');
  });
}
