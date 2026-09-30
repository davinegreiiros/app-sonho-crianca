import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/formatters.dart';
import '../../../../domain/models/rental.dart';
import '../../../../test_keys.dart';
import '../../../../theme/app_colors.dart';
import '../view_models/admin_panel_cubit.dart';
import '../view_models/admin_panel_state.dart';

/// 3d — "Administrativo: praça inteira, auditável" (spec
/// 023-posto-monitor-painel). Tela cheia (`Navigator.push`), mesmo padrão
/// de `BusinessSettingsView` — total faturado hoje, uma linha por turno
/// (posto/monitor/loc/bruto/status) e a trilha de lançamentos reais do
/// dia, somente leitura.
class AdminPanelView extends StatelessWidget {
  const AdminPanelView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminPanelCubit>().state;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.text,
        leading: IconButton(
          key: TestKeys.adminPanelBackButton,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Administrativo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('FATURADO HOJE · ${state.turnRows.length} POSTOS', style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600, color: AppColors.accent700)),
            Text(formatMoney(state.totalGrossToday), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w600, height: 1.05)),
            Text('${state.totalLocToday} locações', style: TextStyle(fontSize: 12.5, color: AppColors.text.withValues(alpha: 0.65))),
            const SizedBox(height: 22),
            Text('POR POSTO E MONITOR', style: TextStyle(fontSize: 10.5, letterSpacing: 1, fontWeight: FontWeight.w600, color: AppColors.text.withValues(alpha: 0.55))),
            const SizedBox(height: 8),
            if (state.turnRows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('Nenhum turno hoje ainda.', style: TextStyle(fontSize: 12.5, color: AppColors.text.withValues(alpha: 0.6))),
              )
            else
              for (final row in state.turnRows) ...[
                _TurnoRowTile(row: row),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 22),
            Text('TRILHA DE LANÇAMENTOS', style: TextStyle(fontSize: 10.5, letterSpacing: 1, fontWeight: FontWeight.w600, color: AppColors.text.withValues(alpha: 0.55))),
            const SizedBox(height: 8),
            if (state.trail.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('Nenhum lançamento hoje ainda.', style: TextStyle(fontSize: 12.5, color: AppColors.text.withValues(alpha: 0.6))),
              )
            else
              for (final entry in state.trail) _TrailRow(entry: entry),
          ],
        ),
      ),
    );
  }
}

class _TurnoRowTile extends StatelessWidget {
  const _TurnoRowTile({required this.row});
  final TurnoRow row;

  @override
  Widget build(BuildContext context) {
    final statusLabel = row.isOpen
        ? 'ABERTO'
        : (row.diff == null || row.diff!.abs() < 0.005)
            ? 'FECHADO'
            : 'DIF. ${formatMoney(row.diff!)}';
    final statusColor = row.isOpen
        ? AppColors.accent700
        : (row.diff == null || row.diff!.abs() < 0.005)
            ? AppColors.statusOk
            : AppColors.accent2_700;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: row.toy.ink.tint, borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.toy.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(row.monitorName, style: TextStyle(fontSize: 11.5, color: AppColors.text.withValues(alpha: 0.65))),
              ],
            ),
          ),
          Text('${row.locCount} loc.', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Text(formatMoney(row.gross), textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Text(statusLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: statusColor)),
        ],
      ),
    );
  }
}

class _TrailRow extends StatelessWidget {
  const _TrailRow({required this.entry});
  final TrailEntry entry;

  @override
  Widget build(BuildContext context) {
    final r = entry.rental;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '${r.endedAt!.hour.toString().padLeft(2, '0')}:${r.endedAt!.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.text.withValues(alpha: 0.55)),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              r.finishedByMonitorName ?? 'Administrador',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Encerrou '),
                TextSpan(text: r.childName, style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: ' · ${entry.toy.name} · ${r.paymentMethod?.label ?? ''}'),
              ]),
              style: const TextStyle(fontSize: 12.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(formatMoney(r.price), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
