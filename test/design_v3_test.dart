// Widget tests for spec 007 (Revisão de Design v3): category icons, the
// tempo-corrido CTA label, and Configurações opening as a full screen
// instead of a bottom sheet.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/test_keys.dart';
import 'package:sonho_de_crianca/ui/features/app_shell/view_models/app_shell_cubit.dart';
import 'package:sonho_de_crianca/ui/features/business_settings/view_models/business_settings_cubit.dart';
import 'package:sonho_de_crianca/widgets/category_icon.dart';

import 'fakes/fake_business_settings.dart';

Future<AppState> _pumpApp(WidgetTester tester, {RentalRepository? rentalRepository}) async {
  final authRepository = fakeLoggedInAuthRepository();
  await tester.pumpWidget(SonhoDeCriancaApp(
    rentalRepository: rentalRepository,
    authRepository: authRepository,
    businessSettingsRepository: fakeBusinessSettingsRepository(authRepository: authRepository),
    startInPostoAdminMode: true,
  ));
  await tester.pump(const Duration(milliseconds: 400));
  return Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);
}

// Navigation lives in AppShellCubit (spec 021-migracao-shell-app), not
// AppState, since home_shell.dart stopped reading AppState.
void _setTab(WidgetTester tester, AppTab tab) {
  BlocProvider.of<AppShellCubit>(tester.element(find.byType(MaterialApp)), listen: false).setTab(tab);
}

void main() {
  SharedPreferences.setMockInitialValues({});

  testWidgets('catalog card shows the right category icon', (tester) async {
    await _pumpApp(tester);
    _setTab(tester, AppTab.catalog);
    await tester.pump(const Duration(milliseconds: 400));

    // Seed: 'carrinho' is ToyCategory.eletrico.
    final card = find.byKey(TestKeys.toyCardKey('carrinho'));
    final icon = tester.widget<CategoryIcon>(find.descendant(of: card, matching: find.byType(CategoryIcon)));
    expect(icon.category, ToyCategory.eletrico);
  });

  testWidgets('tempo-corrido active card says "Parar e cobrar", fixed-duration says "Finalizar"', (tester) async {
    final state = await _pumpApp(tester, rentalRepository: RentalRepository.withDemoSeed());

    state.openNew();
    state.setDraftToy('cama');
    state.setDraftChild('Tempo Corrido Teste');
    state.setDraftOpenEnded(true);
    state.submitNew();
    final openEnded = state.rentals.firstWhere((r) => r.childName == 'Tempo Corrido Teste');

    _setTab(tester, AppTab.active);
    await tester.pump(const Duration(milliseconds: 400));

    final openEndedCard = find.byKey(TestKeys.activeCardKey(openEnded.id));
    await tester.scrollUntilVisible(openEndedCard, 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(find.descendant(of: openEndedCard, matching: find.text('Parar e cobrar')), findsOneWidget);

    // Seed rental 'a1' has a fixed duration (spec 006 unaffected).
    final fixedCard = find.byKey(TestKeys.activeCardKey('a1'));
    await tester.scrollUntilVisible(fixedCard, -200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(find.descendant(of: fixedCard, matching: find.text('Finalizar')), findsOneWidget);
  });

  testWidgets('gear icon opens Configurações as a full screen, not a bottom sheet', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(TestKeys.settingsGearButton));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byKey(TestKeys.businessNameField), findsOneWidget);
    expect(find.byKey(TestKeys.settingsScreenBackButton), findsOneWidget);
    // A `showModalBottomSheet` puts its content in a `Material` with a
    // `BottomSheet` ancestor; a pushed `MaterialPageRoute` doesn't.
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.byKey(TestKeys.settingsScreenBackButton));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(TestKeys.businessNameField), findsNothing);
  });

  testWidgets('reabrir Configurações na mesma sessão mostra o valor já salvo (spec 024, regressão)', (tester) async {
    await _pumpApp(tester);
    final cubit = BlocProvider.of<BusinessSettingsCubit>(tester.element(find.byType(MaterialApp)), listen: false);

    await tester.tap(find.byKey(TestKeys.settingsGearButton));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Espera o `refresh()` do `initState` resolver de verdade antes de
    // digitar — senão o `setState` que sincroniza os campos (spec 024)
    // pode disparar *depois* que o teste já digitou, apagando o texto.
    await _waitForSettingsForm(tester);

    await tester.enterText(find.byKey(TestKeys.businessNameField), 'Sonho de Criança');
    await tester.enterText(find.byKey(TestKeys.businessCityField), 'Fortaleza');
    await tester.enterText(find.byKey(TestKeys.businessPixKeyField), '85999998888');
    // A árvore só reflete os 3 `enterText` depois de um `pump()` — sem
    // isso o hit-test do tap abaixo ainda vê o snapshot antigo do botão
    // (desabilitado, de antes de preencher o último campo).
    await tester.pump();
    // `ensureVisible` só garante a borda de cima do botão dentro da
    // viewport de teste — a seção "Postos" (atalho pro Catálogo) empurrou
    // o botão pra baixo o bastante que a base dele ainda ficava fora,
    // então o tap errava o alvo; arrasto manual garante margem de sobra.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pump();
    await tester.tap(find.byKey(TestKeys.saveBusinessSettingsButton));
    // Poll em vez de contar frames no chute — o mesmo motivo do
    // `_waitForSettingsForm`: `update()` tem mais de um hop assíncrono
    // (otimista -> await PUT -> notifica de novo) antes do `_save` decidir
    // fechar a tela.
    for (var i = 0; i < 30 && find.byKey(TestKeys.businessNameField).evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(TestKeys.businessNameField), findsNothing); // fechou depois de salvar
    expect(cubit.state.settings.merchantName, 'Sonho de Criança');

    // Reabre — mesmo Cubit/Repository do app inteiro (instância única),
    // já `loaded` da vez anterior. `refresh()` pode resolver pro mesmo
    // status de antes (sem "mudança" nenhuma) — os campos precisam vir
    // preenchidos mesmo assim, não em branco.
    await tester.tap(find.byKey(TestKeys.settingsGearButton));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _waitForSettingsForm(tester);

    expect(find.text('Sonho de Criança'), findsOneWidget);
  });
}

/// Espera o formulário de Configurações aparecer (sai do spinner de
/// `firstLoadPending`) — o `setState` que sincroniza os campos e o que
/// esconde o spinner são o mesmo bloco síncrono (spec 024), então "botão
/// Salvar existe" é exatamente "campos já sincronizados". Mais confiável
/// que contar frames no chute ou espiar `status` isolado (que pode virar
/// `loaded` um microtask antes desse `setState` específico rodar).
Future<void> _waitForSettingsForm(WidgetTester tester, {int maxTries = 30}) async {
  for (var i = 0; i < maxTries; i++) {
    if (find.byKey(TestKeys.saveBusinessSettingsButton).evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
}
