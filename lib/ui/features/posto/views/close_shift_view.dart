import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/formatters.dart';
import '../../../../domain/models/rental.dart';
import '../../../../test_keys.dart';
import '../../../../theme/app_colors.dart';
import '../view_models/posto_session_cubit.dart';

/// 3c — "Fechamento de turno (conferência)" (spec 023-posto-monitor-painel).
/// Esperado por forma de pagamento (das locações encerradas neste turno,
/// calculado em `PostoSessionCubit.beginClosing`), campo de dinheiro
/// contado, diferença colorida, confirmar fecha o `Turno` e volta pra 3a.
class CloseShiftView extends StatelessWidget {
  const CloseShiftView({super.key});

  static const _barColor = {
    PaymentMethod.pix: AppColors.accent,
    PaymentMethod.cartao: AppColors.accent2,
    PaymentMethod.dinheiro: AppColors.processYellow,
  };

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PostoSessionCubit>();
    final state = cubit.state;
    final diff = state.closingDiff;
    final bate = diff != null && diff.abs() < 0.005;
    final diffColor = diff == null
        ? AppColors.text.withValues(alpha: 0.6)
        : bate
            ? AppColors.statusOk
            : AppColors.accent2_700;
    final maxExpected = state.closingExpectedByMethod.values.fold(0.01, (a, v) => v > a ? v : a);
    final now = DateTime.now();
    String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Fechamento de turno', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            Text(
              '${state.monitorName ?? ''} · ${state.turnoOpenedAt == null ? '' : '${hm(state.turnoOpenedAt!)} → ${hm(now)}'}',
              style: TextStyle(fontSize: 12.5, color: AppColors.text.withValues(alpha: 0.7)),
            ),
            Text(
              '${state.closingLocCount} locações · 0 cortesias',
              style: TextStyle(fontSize: 11.5, color: AppColors.text.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 16),
            Text(
              'O SISTEMA ESPERAVA',
              style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600, color: AppColors.text.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 10),
            for (final m in PaymentMethod.values) ...[
              _ExpectedRow(
                label: m.label,
                value: state.closingExpectedByMethod[m] ?? 0,
                fraction: (state.closingExpectedByMethod[m] ?? 0) / maxExpected,
                color: _barColor[m]!,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Quanto tem em dinheiro na sua mão agora?', style: TextStyle(fontSize: 11.5, color: AppColors.text.withValues(alpha: 0.7))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: TestKeys.closingCashField,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 17, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(hintText: '0,00'),
                          onChanged: cubit.setClosingCountedCash,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('DIFERENÇA', style: TextStyle(fontSize: 9.5, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: AppColors.text.withValues(alpha: 0.55))),
                          Text(
                            diff == null ? '—' : formatMoney(diff),
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: diffColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (diff != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(bate ? Icons.check_circle_outline : Icons.error_outline, size: 15, color: diffColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            bate
                                ? 'Caixa bate com o esperado. Pode fechar.'
                                : (diff > 0
                                    ? 'Tem ${formatMoney(diff)} a mais do que o esperado.'
                                    : 'Falta ${formatMoney(diff.abs())} pro esperado.'),
                            style: TextStyle(fontSize: 11.5, color: diffColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.accent100, borderRadius: BorderRadius.circular(2)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.accent700),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Ao fechar, os ${state.closingLocCount} lançamentos deste turno são assinados com seu nome e a hora. Depois disso nada pode ser editado — só corrigido por um novo lançamento.',
                      style: TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.accent900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Revisar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    key: TestKeys.confirmCloseShiftButton,
                    onPressed: () {
                      cubit.confirmCloseTurno();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.bg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Fechar turno'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpectedRow extends StatelessWidget {
  const _ExpectedRow({required this.label, required this.value, required this.fraction, required this.color});
  final String label;
  final double value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 62, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LayoutBuilder(builder: (context, constraints) {
              return Stack(
                children: [
                  Container(height: 8, color: AppColors.text.withValues(alpha: 0.08)),
                  Container(height: 8, width: constraints.maxWidth * fraction.clamp(0, 1), color: color),
                ],
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 68, child: Text(formatMoney(value), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
