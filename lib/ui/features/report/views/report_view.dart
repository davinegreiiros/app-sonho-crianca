import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';
import '../../../../theme/app_colors.dart';
import '../../../../ui/core/formatters.dart';
import '../../../../widgets/animations/cascade.dart';
import '../../../../widgets/animations/pressable.dart';
import '../view_models/report_cubit.dart';
import '../view_models/report_state.dart';

/// Migrated in spec 014-migracao-relatorio: reads/writes through
/// [ReportCubit] instead of `AppState`.
class ReportView extends StatefulWidget {
  const ReportView({super.key});

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> with TickerProviderStateMixin {
  CascadeController? _cascade;

  @override
  void dispose() {
    _cascade?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ReportCubit>();
    final report = cubit.state;
    _cascade ??= CascadeController(this, itemCount: PaymentMethod.values.length);
    final cascade = _cascade!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
      children: [
        _PeriodSelector(cubit: cubit, period: report.period),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(color: AppColors.accent100, borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FATURADO NO PERÍODO',
                style: TextStyle(fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w600, color: AppColors.accent700),
              ),
              Text(
                formatMoney(report.total),
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, height: 1, color: AppColors.accent900),
              ),
              Text(
                '${report.filteredCount} ${report.filteredCount == 1 ? 'locação' : 'locações'} no período',
                style: TextStyle(fontSize: 12, color: AppColors.accent900.withValues(alpha: 0.65)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'POR FORMA DE PAGAMENTO',
          style: TextStyle(fontSize: 10.5, letterSpacing: 1, color: AppColors.text.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < PaymentMethod.values.length; i++)
          cascade.item(
            i,
            child: _PaymentBar(
              method: PaymentMethod.values[i],
              amount: report.paymentBreakdown[PaymentMethod.values[i]] ?? 0,
              total: report.total,
            ),
          ),
        const SizedBox(height: 18),
        Text(
          'POR BRINQUEDO',
          style: TextStyle(fontSize: 10.5, letterSpacing: 1, color: AppColors.text.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 6),
        for (final entry in report.toyBreakdown)
          _ToyBreakdownRow(toy: entry.toy, count: entry.count, amount: entry.total),
        const SizedBox(height: 18),
        Text(
          'HISTÓRICO',
          style: TextStyle(fontSize: 10.5, letterSpacing: 1, color: AppColors.text.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 6),
        if (report.historyList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Sem locações finalizadas nesse período.',
              style: TextStyle(fontSize: 13, color: AppColors.text.withValues(alpha: 0.6)),
            ),
          )
        else
          for (final r in report.historyList) _HistoryRow(rental: r, toy: report.toyById(r.toyId)),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.cubit, required this.period});
  final ReportCubit cubit;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final options = [
      (p: ReportPeriod.today, label: 'Hoje'),
      (p: ReportPeriod.week, label: '14 dias'),
      (p: ReportPeriod.all, label: 'Tudo'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.text.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(3),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(child: _buildSegment(context, options[i], i == options.length - 1)),
        ],
      ),
    );
  }

  Widget _buildSegment(BuildContext context, ({ReportPeriod p, String label}) o, bool isLast) {
    final selected = period == o.p;
    return Pressable(
      child: InkWell(
        onTap: () => cubit.setPeriod(o.p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            border: isLast ? null : Border(right: BorderSide(color: AppColors.text.withValues(alpha: 0.16))),
          ),
          child: Text(
            o.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.bg : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentBar extends StatelessWidget {
  const _PaymentBar({required this.method, required this.amount, required this.total});
  final PaymentMethod method;
  final double amount;
  final double total;

  Color get _barColor => switch (method) {
        PaymentMethod.pix => AppColors.accent,
        PaymentMethod.cartao => AppColors.accent2,
        PaymentMethod.dinheiro => AppColors.processYellow,
      };

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? amount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(method.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 9,
                backgroundColor: AppColors.text.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(_barColor),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(formatMoney(amount), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ToyBreakdownRow extends StatelessWidget {
  const _ToyBreakdownRow({required this.toy, required this.count, required this.amount});
  final Toy toy;
  final int count;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.text.withValues(alpha: 0.08)))),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: toy.ink.dot)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(toy.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Text('${count}x', style: TextStyle(fontSize: 12, color: AppColors.text.withValues(alpha: 0.6))),
          const SizedBox(width: 8),
          Text(formatMoney(amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.rental, required this.toy});
  final Rental rental;
  final Toy toy;

  Color get _payBg => switch (rental.paymentMethod!) {
        PaymentMethod.pix => AppColors.accent100,
        PaymentMethod.cartao => AppColors.accent2_100,
        PaymentMethod.dinheiro => AppColors.yellowTint,
      };

  Color get _payColor => switch (rental.paymentMethod!) {
        PaymentMethod.pix => AppColors.accent700,
        PaymentMethod.cartao => AppColors.accent2_700,
        PaymentMethod.dinheiro => AppColors.yellowFg,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.text.withValues(alpha: 0.08)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${toy.name} · ${rental.childName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(formatRelativeTime(rental.endedAt!), style: TextStyle(fontSize: 11, color: AppColors.text.withValues(alpha: 0.6))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _payBg, borderRadius: BorderRadius.circular(2)),
            child: Text(
              rental.paymentMethod!.label,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _payColor),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(formatMoney(rental.price), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
