// Spec 028-relatorio-dono-whatsapp — relatório do dono: semana/mês de
// calendário, por monitor, caixa do período (mesma regra do fechamento de
// turno) e o resumo em texto que vai pro WhatsApp.
//
// Relógio fixo: quarta-feira 07/10/2026 15:00 — semana começa segunda
// 05/10 00:00, mês começa 01/10 00:00.

import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonho_de_crianca/data/repositories/turno_repository.dart';
import 'package:sonho_de_crianca/domain/models/rental.dart';
import 'package:sonho_de_crianca/domain/models/turno.dart';
import 'package:sonho_de_crianca/domain/text_sharer.dart';
import 'package:sonho_de_crianca/ui/features/posto/view_models/posto_session_cubit.dart';
import 'package:sonho_de_crianca/ui/features/report/view_models/report_cubit.dart';
import 'package:sonho_de_crianca/ui/features/report/view_models/report_state.dart';

import 'fakes/fake_rental_backend.dart';
import 'fakes/fake_toy_backend.dart';

final _now = DateTime(2026, 10, 7, 15);

Rental _done(
  String id, {
  required DateTime endedAt,
  required double price,
  String toyId = 'cama',
  PaymentMethod method = PaymentMethod.pix,
  String? monitor,
}) =>
    Rental(
      id: id,
      toyId: toyId,
      childName: 'Criança Secreta $id',
      guardianName: 'Responsável Secreto $id',
      guardianPhone: '85911112222',
      startedAt: endedAt.subtract(const Duration(minutes: 15)),
      durationMin: 15,
      price: price,
      status: RentalStatus.done,
      endedAt: endedAt,
      paymentMethod: method,
      finishedByMonitorName: monitor,
    );

class _FakeSharer implements TextSharer {
  final shared = <String>[];
  Rect? lastOrigin;

  @override
  Future<void> share(String text, {Rect? origin}) async {
    shared.add(text);
    lastOrigin = origin;
  }
}

ReportCubit _cubit(List<Rental> rentals, {TurnoRepository? turnos, TextSharer? sharer}) {
  final rentalRepository = fakeRentalRepository()..rentals.addAll(rentals);
  return ReportCubit(
    rentalRepository,
    fakeToyRepository(),
    turnoRepository: turnos,
    textSharer: sharer,
    clock: () => _now,
  );
}

void main() {
  group('períodos de calendário', () {
    test('cenário 1 — Semana conta desde segunda 00:00, não antes', () {
      final cubit = _cubit([
        _done('seg', endedAt: DateTime(2026, 10, 5, 0, 30), price: 10),
        _done('qua', endedAt: DateTime(2026, 10, 7, 11), price: 20),
        _done('dom', endedAt: DateTime(2026, 10, 4, 23, 30), price: 40), // semana anterior
      ]);

      cubit.setPeriod(ReportPeriod.week);
      expect(cubit.state.filteredCount, 2);
      expect(cubit.state.total, 30);
      expect(cubit.state.historyList.map((r) => r.id), isNot(contains('dom')));
      cubit.close();
    });

    test('cutoffFor(week) num domingo volta pra segunda anterior', () {
      expect(ReportCubit.cutoffFor(ReportPeriod.week, DateTime(2026, 10, 11, 20)), DateTime(2026, 10, 5));
      expect(ReportCubit.cutoffFor(ReportPeriod.week, DateTime(2026, 10, 5, 8)), DateTime(2026, 10, 5));
    });

    test('cenário 2 — Mês conta só o mês atual', () {
      final cubit = _cubit([
        _done('set', endedAt: DateTime(2026, 9, 30, 22), price: 50),
        _done('out1', endedAt: DateTime(2026, 10, 1, 9), price: 15),
        _done('out2', endedAt: DateTime(2026, 10, 6, 9), price: 25),
      ]);

      cubit.setPeriod(ReportPeriod.month);
      expect(cubit.state.filteredCount, 2);
      expect(cubit.state.total, 40);
      expect(cubit.state.toyBreakdown.single.total, 40);
      cubit.close();
    });
  });

  test('locação cancelada (done sem pagamento, spec 026) não entra no faturamento', () {
    final cancelled = Rental(
      id: 'cancelada',
      toyId: 'cama',
      childName: 'X',
      guardianName: 'Y',
      startedAt: DateTime(2026, 10, 7, 9),
      durationMin: 15,
      price: 99,
      status: RentalStatus.done,
      endedAt: DateTime(2026, 10, 7, 9, 5),
    );
    final cubit = _cubit([cancelled, _done('ok', endedAt: DateTime(2026, 10, 7, 10), price: 10)]);

    expect(cubit.state.filteredCount, 1);
    expect(cubit.state.total, 10);
    expect(cubit.state.monitorBreakdown.fold(0.0, (a, r) => a + r.total), 10);
    cubit.close();
  });

  test('cenário 3 — por monitor inclui "Administrador" e soma igual ao total', () {
    final cubit = _cubit([
      _done('g1', endedAt: DateTime(2026, 10, 7, 9), price: 10, monitor: 'Gustavo'),
      _done('g2', endedAt: DateTime(2026, 10, 7, 10), price: 15, monitor: 'Gustavo'),
      _done('a1', endedAt: DateTime(2026, 10, 7, 11), price: 30, monitor: 'Ana'),
      _done('adm', endedAt: DateTime(2026, 10, 7, 12), price: 5),
    ]);

    final rows = cubit.state.monitorBreakdown;
    expect(rows.map((r) => r.name), ['Ana', 'Gustavo', adminMonitorLabel]); // maior valor primeiro
    expect(rows.firstWhere((r) => r.name == 'Gustavo').count, 2);
    expect(rows.fold(0.0, (a, r) => a + r.total), cubit.state.total);
    cubit.close();
  });

  group('caixa do período', () {
    test('cenário 4 — diferença do relatório é a mesma que o monitor viu ao fechar', () {
      final rentalRepository = fakeRentalRepository();
      final turnoRepository = TurnoRepository();
      final posto = PostoSessionCubit(fakeToyRepository(), rentalRepository, turnoRepository);

      posto.openOrResume('cama', monitorName: 'Gustavo');
      final openedAt = turnoRepository.turnos.single.openedAt;
      rentalRepository.rentals.addAll([
        _done('d1', endedAt: openedAt, price: 30, method: PaymentMethod.dinheiro, monitor: 'Gustavo'),
        _done('p1', endedAt: openedAt, price: 15, method: PaymentMethod.pix, monitor: 'Gustavo'),
        // Mesmo brinquedo e janela, mas recebida por outra pessoa: não é do caixa do Gustavo.
        _done('outro', endedAt: openedAt, price: 50, method: PaymentMethod.dinheiro, monitor: 'Ana'),
      ]);

      posto.beginClosing();
      posto.setClosingCountedCash('10'); // esperado 30 em dinheiro → falta 20
      final diffSeenByMonitor = posto.state.closingDiff;
      posto.confirmCloseTurno();

      // Turno fechado no "agora" real; relatório olha 1 min depois.
      final report = ReportCubit(
        rentalRepository,
        fakeToyRepository(),
        turnoRepository: turnoRepository,
        clock: () => turnoRepository.turnos.single.closedAt!.add(const Duration(minutes: 1)),
      );

      expect(diffSeenByMonitor, -20);
      expect(report.state.closedTurnosCount, 1);
      expect(report.state.cashDiffTurnos.single.diff, diffSeenByMonitor);
      expect(report.state.cashDiffTotal, -20);
      report.close();
      posto.close();
    });

    test('cenário 5 — turno que bateu não aparece como diferença', () {
      final turnos = TurnoRepository();
      turnos.turnos.add(Turno(
        id: 't-ok',
        toyId: 'cama',
        monitorName: 'Ana',
        openedAt: DateTime(2026, 10, 6, 8),
        closedAt: DateTime(2026, 10, 6, 18),
        countedCash: 25,
      ));
      final cubit = _cubit(
        [_done('d', endedAt: DateTime(2026, 10, 6, 12), price: 25, method: PaymentMethod.dinheiro, monitor: 'Ana')],
        turnos: turnos,
      );

      cubit.setPeriod(ReportPeriod.week);
      expect(cubit.state.closedTurnosCount, 1);
      expect(cubit.state.cashDiffTurnos, isEmpty);
      cubit.close();
    });

    test('turno fechado fora do período não entra', () {
      final turnos = TurnoRepository();
      turnos.turnos.add(Turno(
        id: 't-old',
        toyId: 'cama',
        monitorName: 'Ana',
        openedAt: DateTime(2026, 9, 20, 8),
        closedAt: DateTime(2026, 9, 20, 18),
        countedCash: 0,
      ));
      final cubit = _cubit(
        [_done('d', endedAt: DateTime(2026, 9, 20, 12), price: 25, method: PaymentMethod.dinheiro, monitor: 'Ana')],
        turnos: turnos,
      );

      cubit.setPeriod(ReportPeriod.month);
      expect(cubit.state.closedTurnosCount, 0);
      cubit.setPeriod(ReportPeriod.all);
      expect(cubit.state.closedTurnosCount, 1);
      expect(cubit.state.cashDiffTurnos.single.diff, -25);
      cubit.close();
    });
  });

  group('resumo em texto', () {
    test('cenário 6 — shareSummary manda o texto do período atual pro sharer', () async {
      final sharer = _FakeSharer();
      final cubit = _cubit([
        _done('g1', endedAt: DateTime(2026, 10, 7, 9), price: 10, monitor: 'Gustavo'),
      ], sharer: sharer);
      cubit.setPeriod(ReportPeriod.month);

      await cubit.shareSummary(origin: const Rect.fromLTWH(0, 0, 10, 10));

      expect(sharer.shared, hasLength(1));
      expect(sharer.shared.single, startsWith('Sonho de Criança — Outubro/2026'));
      expect(sharer.lastOrigin, const Rect.fromLTWH(0, 0, 10, 10));
      cubit.close();
    });

    test('texto tem total, pagamento, brinquedo, monitor e caixa', () {
      final turnos = TurnoRepository();
      turnos.turnos.add(Turno(
        id: 't1',
        toyId: 'cama',
        monitorName: 'Gustavo',
        openedAt: DateTime(2026, 10, 6, 8),
        closedAt: DateTime(2026, 10, 6, 18),
        countedCash: 10,
      ));
      final cubit = _cubit([
        _done('d', endedAt: DateTime(2026, 10, 6, 12), price: 30, method: PaymentMethod.dinheiro, monitor: 'Gustavo'),
        _done('p', endedAt: DateTime(2026, 10, 7, 12), price: 15, monitor: 'Ana'),
      ], turnos: turnos);
      cubit.setPeriod(ReportPeriod.week);

      final text = cubit.summaryText();
      expect(text, startsWith('Sonho de Criança — Semana de 05/10 a 07/10/2026'));
      expect(text, contains('Total: R\$ 45,00 (2 locações)'));
      expect(text, contains('Dinheiro: R\$ 30,00'));
      expect(text, contains('Pix: R\$ 15,00'));
      expect(text, contains('Gustavo: R\$ 30,00 (1)'));
      expect(text, contains('Caixa: 1 turno, 1 com diferença, saldo -R\$ 20,00'));
      expect(text, contains('Gustavo · ${cubit.state.toyById('cama').name} · 06/10: -R\$ 20,00'));
      cubit.close();
    });

    test('cenário 8 — nenhum dado de criança/responsável no texto', () {
      final cubit = _cubit([
        _done('x1', endedAt: DateTime(2026, 10, 7, 9), price: 10, monitor: 'Gustavo'),
        _done('x2', endedAt: DateTime(2026, 10, 7, 10), price: 20),
      ]);
      for (final period in ReportPeriod.values) {
        cubit.setPeriod(period);
        final text = cubit.summaryText();
        expect(text, isNot(contains('Criança Secreta')));
        expect(text, isNot(contains('Responsável Secreto')));
        expect(text, isNot(contains('85911112222')));
      }
      cubit.close();
    });

    test('cenário 7 — período vazio gera texto legível, sem seções zeradas', () {
      final cubit = _cubit([]);
      final text = cubit.summaryText();
      expect(text, 'Sonho de Criança — Hoje, 07/10/2026\nNenhuma locação finalizada no período.');
      cubit.close();
    });
  });
}
