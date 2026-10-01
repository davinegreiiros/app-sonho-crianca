// Widget/unit tests for spec 023-posto-monitor-painel: abrir posto (3a),
// tela do monitor (3b), fechamento de turno (3c) e painel administrativo
// (3d).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/repositories/toy_repository.dart';
import 'package:sonho_de_crianca/data/repositories/turno_repository.dart';
import 'package:sonho_de_crianca/data/services/app_database.dart';
import 'package:sonho_de_crianca/domain/formatters.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/domain/models/turno.dart';
import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/test_keys.dart';
import 'package:sonho_de_crianca/ui/features/posto/view_models/posto_session_cubit.dart';
import 'package:sonho_de_crianca/ui/features/posto/view_models/posto_session_state.dart';

/// Multi-frame settle — mesmo padrão já usado em
/// `full_app_journey_test.dart` (`_settleFrames`): navegação
/// (`Navigator.push`) e o `BlocBuilder` raiz que troca 3a/3b/`HomeShell`
/// precisam de mais de um frame pra assentar, um único `pump(duration)`
/// grande às vezes não é suficiente.
Future<void> _settle(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('abrir um posto livre cria um turno e trava o brinquedo em 3b', (tester) async {
    final turnoRepository = TurnoRepository();
    await tester.pumpWidget(SonhoDeCriancaApp(turnoRepository: turnoRepository));
    await _settle(tester);

    // Começa em 3a (nenhum posto escolhido ainda).
    expect(find.byKey(TestKeys.postoRow('cama')), findsOneWidget);
    expect(find.byKey(TestKeys.exitPostoButton), findsNothing);

    await tester.tap(find.byKey(TestKeys.postoRow('cama')));
    await tester.pump();
    await tester.enterText(find.byKey(TestKeys.postoNameField), 'Gustavo');
    // O nome digitado empurra o botão "Entrar no posto" pra fora da
    // viewport de teste (800x600) — `ensureVisible` só garante a borda
    // inicial visível, não o botão inteiro; um arrasto extra garante que
    // o `tap()` abaixo realmente acerta o widget.
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pump();
    await tester.tap(find.byKey(TestKeys.postoEnterButton));
    await _settle(tester);

    // Agora em 3b, travado na Cama Elástica.
    expect(find.byKey(TestKeys.exitPostoButton), findsOneWidget);
    expect(find.text('Cama Elástica'), findsOneWidget);
    expect(find.text('Gustavo'), findsOneWidget);
    expect(turnoRepository.turnos, hasLength(1));
    expect(turnoRepository.turnos.single.toyId, 'cama');
    expect(turnoRepository.turnos.single.monitorName, 'Gustavo');
    expect(turnoRepository.turnos.single.isOpen, isTrue);
  });

  testWidgets('tocar um posto livre destaca qual brinquedo foi selecionado', (tester) async {
    await tester.pumpWidget(SonhoDeCriancaApp(turnoRepository: TurnoRepository()));
    await _settle(tester);

    expect(find.text('VOCÊ'), findsNothing);

    await tester.tap(find.byKey(TestKeys.postoRow('cama')));
    await tester.pump();

    expect(find.descendant(of: find.byKey(TestKeys.postoRow('cama')), matching: find.text('VOCÊ')), findsOneWidget);
    expect(find.text('Seu nome no posto · Cama Elástica'), findsOneWidget);
  });

  testWidgets('tocar um posto já ocupado retoma o mesmo turno, sem duplicar', (tester) async {
    final turnoRepository = TurnoRepository();
    final existing = turnoRepository.open('cama', 'Ana');

    await tester.pumpWidget(SonhoDeCriancaApp(turnoRepository: turnoRepository));
    await _settle(tester);

    expect(find.textContaining('Ana · turno desde'), findsOneWidget);

    await tester.tap(find.byKey(TestKeys.postoRow('cama')));
    await _settle(tester);

    // Sem o campo de nome — retomou direto.
    expect(find.byKey(TestKeys.postoNameField), findsNothing);
    expect(find.text('Ana'), findsOneWidget);
    expect(turnoRepository.turnos, hasLength(1));
    expect(turnoRepository.turnos.single.id, existing.id);
  });

  testWidgets('fechamento de turno calcula esperado e diferença de caixa', (tester) async {
    final turnoOpenedAt = DateTime.now().subtract(const Duration(hours: 1));
    final turnoRepository = TurnoRepository();
    turnoRepository.turnos.add(Turno(id: 't1', toyId: 'cama', monitorName: 'Gustavo', openedAt: turnoOpenedAt));
    final rentalRepository = RentalRepository();
    rentalRepository.rentals.add(Rental(
      id: 'r1',
      toyId: 'cama',
      childName: 'Manuela',
      guardianName: 'Bruno',
      startedAt: turnoOpenedAt.add(const Duration(minutes: 5)),
      durationMin: 30,
      price: 15,
      status: RentalStatus.done,
      endedAt: turnoOpenedAt.add(const Duration(minutes: 35)),
      paymentMethod: PaymentMethod.dinheiro,
      finishedByMonitorName: 'Gustavo',
    ));

    await tester.pumpWidget(SonhoDeCriancaApp(rentalRepository: rentalRepository, turnoRepository: turnoRepository));
    await _settle(tester);

    await tester.tap(find.byKey(TestKeys.postoRow('cama')));
    await _settle(tester);
    await tester.tap(find.byKey(TestKeys.closeShiftButton));
    await _settle(tester);

    expect(find.text(formatMoney(15)), findsOneWidget); // esperado em Dinheiro

    await tester.enterText(find.byKey(TestKeys.closingCashField), '15');
    await tester.pump();
    final sessionCubit = BlocProvider.of<PostoSessionCubit>(tester.element(find.byType(MaterialApp)), listen: false);
    expect(sessionCubit.state.closingDiff, 0);

    await tester.ensureVisible(find.byKey(TestKeys.confirmCloseShiftButton));
    await tester.tap(find.byKey(TestKeys.confirmCloseShiftButton));
    await _settle(tester);

    // Volta pra 3a, posto livre de novo.
    expect(find.byKey(TestKeys.postoNameField), findsNothing);
    expect(find.text('LIVRE'), findsWidgets);
    final turno = turnoRepository.turnos.single;
    expect(turno.isOpen, isFalse);
    expect(turno.countedCash, 15);
  });

  testWidgets('painel administrativo soma faturamento e lista turnos de hoje', (tester) async {
    final now = DateTime.now();
    final rentalRepository = RentalRepository();
    rentalRepository.rentals.add(Rental(
      id: 'r1',
      toyId: 'cama',
      childName: 'Manuela',
      guardianName: 'Bruno',
      startedAt: now.subtract(const Duration(minutes: 30)),
      durationMin: 30,
      price: 15,
      status: RentalStatus.done,
      endedAt: now,
      paymentMethod: PaymentMethod.dinheiro,
      finishedByMonitorName: 'Gustavo',
    ));
    final turnoRepository = TurnoRepository();
    turnoRepository.turnos.add(Turno(id: 't1', toyId: 'cama', monitorName: 'Gustavo', openedAt: now.subtract(const Duration(hours: 1))));

    await tester.pumpWidget(SonhoDeCriancaApp(
      rentalRepository: rentalRepository,
      turnoRepository: turnoRepository,
      startInPostoAdminMode: true,
    ));
    await _settle(tester);

    await tester.tap(find.byKey(TestKeys.adminPanelButton));
    await _settle(tester);

    expect(find.text(formatMoney(15)), findsWidgets);
    expect(find.textContaining('1 locações'), findsOneWidget);
    expect(find.text('Gustavo'), findsWidgets); // linha do turno + autor na trilha
    expect(find.textContaining('Encerrou'), findsOneWidget);
  });

  test('PostoSessionCubit.openOrResume nunca abre 2 turnos pro mesmo toyId', () {
    final turnoRepository = TurnoRepository();
    final cubit = PostoSessionCubit(ToyRepository(), RentalRepository(), turnoRepository);

    cubit.openOrResume('cama', monitorName: 'Gustavo');
    cubit.exitToSelection();
    cubit.openOrResume('cama', monitorName: 'Ana'); // ainda aberto por Gustavo — retoma, ignora "Ana"

    expect(turnoRepository.turnos, hasLength(1));
    expect(cubit.state.monitorName, 'Gustavo');
    expect(cubit.state.mode, PostoMode.monitor);
    cubit.close();
  });

  group('migração de schema v1 -> v2', () {
    late String path;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      path = '${Directory.systemTemp.path}/sonho_de_crianca_migration_test_${DateTime.now().microsecondsSinceEpoch}.db';
    });

    tearDown(() async {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    });

    test('banco antigo (v1) ganha as colunas/tabela novas sem perder locação existente', () async {
      // Simula um banco v1 real (schema de antes desta spec).
      final v1 = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE rentals (
              id TEXT PRIMARY KEY,
              toy_id TEXT NOT NULL,
              child_name TEXT NOT NULL,
              guardian_name TEXT NOT NULL,
              guardian_phone TEXT NOT NULL,
              started_at INTEGER NOT NULL,
              duration_min INTEGER,
              rate_per_minute REAL,
              price REAL NOT NULL,
              status TEXT NOT NULL,
              ended_at INTEGER,
              payment_method TEXT
            )
          ''');
        },
      );
      await v1.insert('rentals', {
        'id': 'old1',
        'toy_id': 'cama',
        'child_name': 'Antigo',
        'guardian_name': '—',
        'guardian_phone': '',
        'started_at': DateTime.now().millisecondsSinceEpoch,
        'duration_min': 30,
        'rate_per_minute': null,
        'price': 15.0,
        'status': 'done',
        'ended_at': DateTime.now().millisecondsSinceEpoch,
        'payment_method': 'dinheiro',
      });
      await v1.close();

      final appDatabase = AppDatabase(path: path);
      final db = await appDatabase.database;

      final tables = (await db.query('sqlite_master', where: "type = 'table'", columns: ['name'])).map((t) => t['name']).toSet();
      expect(tables, contains('turnos'));

      final rows = await db.query('rentals', where: 'id = ?', whereArgs: ['old1']);
      expect(rows, hasLength(1));
      expect(rows.single['child_name'], 'Antigo');
      expect(rows.single['created_by_monitor_name'], isNull);

      await appDatabase.close();
    });
  });
}
