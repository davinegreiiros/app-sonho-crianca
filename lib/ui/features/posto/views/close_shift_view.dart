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

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PostoSessionCubit>();
    final state = cubit.state;
    final diff = state.closingDiff;
    final diffColor = diff == null
        ? AppColors.text.withValues(alpha: 0.6)
        : diff.abs() < 0.005
            ? AppColors.statusOk
            : AppColors.accent2_700;

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
              '${state.monitorName ?? ''} · esperado por forma de pagamento',
              style: TextStyle(fontSize: 12.5, color: AppColors.text.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 14),
            for (final m in PaymentMethod.values) ...[
              _ExpectedRow(label: m.label, value: state.closingExpectedByMethod[m] ?? 0),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 10),
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
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
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
          ],
        ),
      ),
    );
  }
}

class _ExpectedRow extends StatelessWidget {
  const _ExpectedRow({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 74, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        Expanded(child: Container(height: 1, color: AppColors.divider)),
        const SizedBox(width: 10),
        Text(formatMoney(value), style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
