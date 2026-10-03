import '../../../../domain/formatters.dart';
import '../../../../domain/models/rental.dart';
import 'report_cubit.dart';
import 'report_state.dart';

/// Resumo em texto do relatório, pra mandar pelo WhatsApp (spec
/// 028-relatorio-dono-whatsapp).
///
/// Só lê agregados do [ReportState] (totais, nomes de brinquedo e de
/// monitor) — nunca `historyList`, que é onde estão nome de criança e de
/// responsável. Esse dado não sai do aparelho por aqui (constitution,
/// Segurança).
String buildReportSummary(ReportState state) {
  final lines = <String>['Sonho de Criança — ${_periodLabel(state.period, state.now)}'];

  if (state.filteredCount == 0) {
    lines.add('Nenhuma locação finalizada no período.');
  } else {
    lines.add('Total: ${formatMoney(state.total)} (${_plural(state.filteredCount, 'locação', 'locações')})');

    lines
      ..add('')
      ..add('Por pagamento');
    for (final m in PaymentMethod.values) {
      lines.add('${m.label}: ${formatMoney(state.paymentBreakdown[m] ?? 0)}');
    }

    lines
      ..add('')
      ..add('Por brinquedo');
    for (final e in state.toyBreakdown) {
      lines.add('${e.toy.name}: ${formatMoney(e.total)} (${e.count})');
    }

    lines
      ..add('')
      ..add('Por monitor');
    for (final e in state.monitorBreakdown) {
      lines.add('${e.name}: ${formatMoney(e.total)} (${e.count})');
    }
  }

  if (state.closedTurnosCount > 0) {
    lines.add('');
    if (state.cashDiffTurnos.isEmpty) {
      lines.add('Caixa: bateu em todos os ${_plural(state.closedTurnosCount, 'turno', 'turnos')}');
    } else {
      lines.add(
        'Caixa: ${_plural(state.closedTurnosCount, 'turno', 'turnos')}, '
        '${state.cashDiffTurnos.length} com diferença, saldo ${formatSignedMoney(state.cashDiffTotal)}',
      );
      for (final e in state.cashDiffTurnos) {
        lines.add('${e.turno.monitorName} · ${e.toy.name} · ${_dayMonth(e.turno.closedAt!)}: ${formatSignedMoney(e.diff)}');
      }
    }
  }

  return lines.join('\n');
}

/// `+R$ 5,00` / `-R$ 20,00` / `R$ 0,00` — diferença de caixa com sinal.
String formatSignedMoney(double value) {
  if (value.abs() < 0.005) return formatMoney(0);
  return '${value > 0 ? '+' : '-'}${formatMoney(value.abs())}';
}

const _months = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

String _two(int n) => n.toString().padLeft(2, '0');
String _dayMonth(DateTime d) => '${_two(d.day)}/${_two(d.month)}';
String _date(DateTime d) => '${_dayMonth(d)}/${d.year}';
String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

String _periodLabel(ReportPeriod period, DateTime now) => switch (period) {
      ReportPeriod.today => 'Hoje, ${_date(now)}',
      ReportPeriod.week => 'Semana de ${_dayMonth(ReportCubit.cutoffFor(period, now))} a ${_date(now)}',
      ReportPeriod.month => '${_months[now.month - 1]}/${now.year}',
      ReportPeriod.all => 'Todo o período',
    };
