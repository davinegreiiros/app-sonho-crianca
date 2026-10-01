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
    final openCount = state.turnRows.where((r) => r.isOpen).length;
    final closedCount = state.turnRows.length - openCount;
    final divergentCount = state.turnRows.where((r) => r.diff != null && r.diff!.abs() >= 0.005).length;
    final rowsGross = state.turnRows.fold(0.0, (a, r) => a + r.gross);
    final rowsLoc = state.turnRows.fold(0, (a, r) => a + r.locCount);

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
            Text(
              'FATURADO HOJE · ${state.turnRows.length} POSTO${state.turnRows.length == 1 ? '' : 'S'}',
              style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600, color: AppColors.accent700),
            ),
            Text(formatMoney(state.totalGrossToday), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w600, height: 1.05)),
            Text(
              '${state.totalLocToday} locações'
              '${state.turnRows.isEmpty ? '' : ' · $closedCount turno${closedCount == 1 ? '' : 's'} fechado${closedCount == 1 ? '' : 's'}, $openCount aberto${openCount == 1 ? '' : 's'}'}',
              style: TextStyle(fontSize: 12.5, color: AppColors.text.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 22),
            Text('POR POSTO E MONITOR', style: TextStyle(fontSize: 10.5, letterSpacing: 1, fontWeight: FontWeight.w600, color: AppColors.text.withValues(alpha: 0.55))),
            const SizedBox(height: 8),
            if (state.turnRows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('Nenhum turno hoje ainda.', style: TextStyle(fontSize: 12.5, color: AppColors.text.withValues(alpha: 0.6))),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                child: Row(
                  children: [
                    const Expanded(child: _ColHeader('POSTO · MONITOR')),
                    const SizedBox(width: 44, child: _ColHeader('LOC.', align: TextAlign.right)),
                    const SizedBox(width: 10),
                    const SizedBox(width: 78, child: _ColHeader('BRUTO', align: TextAlign.right)),
                    const SizedBox(width: 10),
                    const SizedBox(width: 92, child: _ColHeader('CONFERÊNCIA', align: TextAlign.right)),
                  ],
                ),
              ),
              Container(height: 1, color: AppColors.divider),
              const SizedBox(height: 4),
              for (final row in state.turnRows) ...[
                _TurnoRowTile(row: row),
                const SizedBox(height: 2),
              ],
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.text, width: 2))),
                child: Row(
                  children: [
                    const Expanded(child: Text('Total da praça', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    SizedBox(width: 44, child: Text('$rowsLoc', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 78,
                      child: Text(formatMoney(rowsGross), textAlign: TextAlign.right, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 92,
                      child: Text(
                        divergentCount == 0 ? '—' : '$divergentCount divergência${divergentCount == 1 ? '' : 's'}',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, color: divergentCount == 0 ? AppColors.text.withValues(alpha: 0.5) : AppColors.accent2_700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Text('TRILHA DE LANÇAMENTOS', style: TextStyle(fontSize: 10.5, letterSpacing: 1, fontWeight: FontWeight.w600, color: AppColors.text.withValues(alpha: 0.55))),
                const SizedBox(width: 8),
                Text('somente leitura', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.text.withValues(alpha: 0.4))),
              ],
            ),
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

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.text, {this.align = TextAlign.left});
  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(fontSize: 9.5, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: AppColors.text.withValues(alpha: 0.45)),
    );
  }
}

class _TurnoRowTile extends StatelessWidget {
  const _TurnoRowTile({required this.row});
  final TurnoRow row;

  @override
  Widget build(BuildContext context) {
    final divergente = !row.isOpen && row.diff != null && row.diff!.abs() >= 0.005;
    final IconData statusIcon;
    final String statusText;
    final Color statusColor;
    if (row.isOpen) {
      statusIcon = Icons.circle;
      statusText = 'turno aberto';
      statusColor = AppColors.accent700;
    } else if (divergente) {
      statusIcon = Icons.warning_amber_rounded;
      statusText = row.diff! < 0 ? 'falta ${formatMoney(row.diff!.abs())}' : 'sobra ${formatMoney(row.diff!)}';
      statusColor = AppColors.accent2_700;
    } else {
      statusIcon = Icons.check_circle;
      statusText = 'confere';
      statusColor = AppColors.statusOk;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: divergente ? AppColors.accent2_100 : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 9),
            child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: row.toy.ink.dot)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.toy.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(row.monitorName, style: TextStyle(fontSize: 11.5, color: AppColors.text.withValues(alpha: 0.65))),
              ],
            ),
          ),
          SizedBox(width: 44, child: Text('${row.locCount}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5))),
          const SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Text(formatMoney(row.gross), textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Flexible(child: Text(statusText, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: statusColor))),
              ],
            ),
          ),
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
    final id = r.id.length <= 4 ? r.id : r.id.substring(r.id.length - 4);
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
          const SizedBox(width: 8),
          Text('#$id', style: TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: AppColors.text.withValues(alpha: 0.35))),
        ],
      ),
    );
  }
}
