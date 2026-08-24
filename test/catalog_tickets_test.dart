// Widget tests for spec 003 (catálogo — tickets de disponibilidade + tipo
// obrigatório): ticket count/state per card, "+N" overflow above the
// visible cap, and the required-category validation on "Novo brinquedo".

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/repositories/toy_repository.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/state/app_state.dart';
import 'package:sonho_de_crianca/test_keys.dart';
import 'package:sonho_de_crianca/theme/app_colors.dart';
import 'package:sonho_de_crianca/ui/features/catalog/view_models/toy_catalog_cubit.dart';
import 'package:sonho_de_crianca/ui/features/catalog/views/add_toy_sheet_view.dart';

/// Ticket widgets are private (`_TicketStub`) to `catalog_view.dart`, so
/// they're matched by runtime type name and their `free` field is read
/// dynamically — a normal way to probe a private widget from a test in a
/// different library without exposing it publicly just for testing.
Finder _ticketsIn(Finder card) =>
    find.descendant(of: card, matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TicketStub'));

bool _isFree(Widget ticket) => (ticket as dynamic).free as bool;

Future<AppState> _pumpApp(WidgetTester tester, {RentalRepository? rentalRepository}) async {
  await tester.pumpWidget(SonhoDeCriancaApp(rentalRepository: rentalRepository));
  await tester.pump(const Duration(milliseconds: 400));
  final state = Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);
  state.setTab(AppTab.catalog);
  await tester.pump(const Duration(milliseconds: 400));
  return state;
}

void main() {
  // AppState() loads business Pix settings via SharedPreferences (spec
  // 004) — mock it so that hits the in-memory fake instead of a real
  // platform channel with nothing listening on the other end.
  SharedPreferences.setMockInitialValues({});

  testWidgets('mixed card shows one free and one in-use ticket', (tester) async {
    await _pumpApp(tester, rentalRepository: RentalRepository.withDemoSeed());

    // Seed: 'carrinho' has qty 2, 1 active rental against it (a1).
    final card = find.byKey(TestKeys.toyCardKey('carrinho'));
    expect(card, findsOneWidget);

    final tickets = tester.widgetList(_ticketsIn(card)).toList();
    expect(tickets, hasLength(2));
    expect(tickets.where(_isFree), hasLength(1));
    expect(tickets.where((t) => !_isFree(t)), hasLength(1));
  });

  testWidgets('fully-booked card shows every ticket as in-use', (tester) async {
    final state = await _pumpApp(tester);

    // 'cama' has qty 1 and no active rental in the seed — rent its only
    // unit out so every ticket on the card should read as in-use.
    state.setDraftToy('cama');
    state.setDraftChild('Teste Ticket');
    state.submitNew();
    await tester.pump(const Duration(milliseconds: 400));

    final card = find.byKey(TestKeys.toyCardKey('cama'));
    final tickets = tester.widgetList(_ticketsIn(card)).toList();
    expect(tickets, hasLength(1));
    expect(tickets.every((t) => !_isFree(t)), isTrue);
  });

  testWidgets('all-free card shows every ticket as free', (tester) async {
    await _pumpApp(tester);

    // 'piscina' has qty 1 and no active rental in the seed.
    final card = find.byKey(TestKeys.toyCardKey('piscina'));
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
    final tickets = tester.widgetList(_ticketsIn(card)).toList();
    expect(tickets, hasLength(1));
    expect(tickets.every(_isFree), isTrue);
  });

  testWidgets('qty above the visible cap folds the rest into "+N"', (tester) async {
    final state = await _pumpApp(tester);

    state.addToy(
      name: 'Brinquedo Grandão',
      price: 10,
      blockMin: 15,
      ink: ToyInk.cyan,
      imageKey: 'outro',
      category: ToyCategory.outro,
      qty: 10,
    );
    await tester.pump(const Duration(milliseconds: 400));

    final newToy = state.toys.last;
    final card = find.byKey(TestKeys.toyCardKey(newToy.id));
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();

    final tickets = tester.widgetList(_ticketsIn(card)).toList();
    expect(tickets, hasLength(6)); // capped at the visible limit
    expect(find.descendant(of: card, matching: find.text('+4')), findsOneWidget);
  });

  testWidgets('catalog card shows a category tag', (tester) async {
    await _pumpApp(tester);

    final card = find.byKey(TestKeys.toyCardKey('carrinho'));
    expect(find.descendant(of: card, matching: find.text('Elétrico')), findsOneWidget);
  });

  testWidgets('AddToySheet requires a category before it can be saved', (tester) async {
    // AddToySheetView (spec 012) writes through ToyCatalogCubit, not
    // AppState — no ChangeNotifierProvider<AppState> needed here anymore.
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => ToyCatalogCubit(ToyRepository(), RentalRepository()),
        child: const MaterialApp(home: Scaffold(body: AddToySheetView())),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Touro Mecânico');
    await tester.pump();

    // Name + defaults are already valid, but no category picked yet.
    final submit = tester.widget<ElevatedButton>(find.byKey(TestKeys.addToySubmitButton));
    expect(submit.onPressed, isNull);

    await tester.tap(find.byKey(TestKeys.categoryOption('outro')));
    await tester.pump();

    final submitAfter = tester.widget<ElevatedButton>(find.byKey(TestKeys.addToySubmitButton));
    expect(submitAfter.onPressed, isNotNull);
  });

  testWidgets('AddToySheet suggests the icon\'s label as the toy name, except for "Outro"', (tester) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => ToyCatalogCubit(ToyRepository(), RentalRepository()),
        child: const MaterialApp(home: Scaffold(body: AddToySheetView())),
      ),
    );
    await tester.pump();

    final nameField = find.byType(TextField).first;
    final iconGrid = find.byType(GridView);

    // Empty name field -> selecting an icon suggests its label. 'cama' is
    // on the grid's first (visible without scrolling) page.
    await tester.tap(find.byKey(TestKeys.toyIconOption('cama')));
    await tester.pump();
    expect(tester.widget<TextField>(nameField).controller!.text, 'Cama elástica');

    // Editing the name by hand -> switching icons doesn't clobber it.
    await tester.enterText(nameField, 'Nome Customizado');
    await tester.pump();
    await tester.tap(find.byKey(TestKeys.toyIconOption('pula')));
    await tester.pump();
    expect(tester.widget<TextField>(nameField).controller!.text, 'Nome Customizado');

    // "Outro" never has a label to suggest — scrolled into view since it's
    // the grid's last item (the icon grid has its own inner Scrollable,
    // nested inside the sheet's outer one).
    await tester.enterText(nameField, '');
    await tester.pump();
    final iconScrollable = find.descendant(of: iconGrid, matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.byKey(TestKeys.toyIconOption('outro')), 200, scrollable: iconScrollable);
    await tester.tap(find.byKey(TestKeys.toyIconOption('outro')));
    await tester.pump();
    expect(tester.widget<TextField>(nameField).controller!.text, isEmpty);
  });
}
