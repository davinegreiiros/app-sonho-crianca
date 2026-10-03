import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/rental_repository.dart';
import '../../../../data/repositories/toy_repository.dart';
import '../../../../domain/formatters.dart';
import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';
import '../../../../test_keys.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/animations/print_strip.dart';
import '../../../../widgets/modal_launchers.dart';
import '../../../core/initials_avatar.dart';
import '../../rental/view_models/active_rentals_cubit.dart';
import '../view_models/posto_session_cubit.dart';
import 'close_shift_view.dart';

/// 3b — "Posto do monitor: um brinquedo só" (spec 023-posto-monitor-painel).
/// Mostra só as locações ativas do `toyId` do posto (filtra
/// `ActiveRentalsCubit.state.activeRentals`, que continua global — o modo
/// administrador ainda precisa ver todas), "Colocar criança" abre a nova
/// locação de sempre com o brinquedo já travado, e o rodapé some pro
/// fechamento de turno (3c).
class MonitorPostoView extends StatelessWidget {
  const MonitorPostoView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<PostoSessionCubit>().state;
    final toyId = session.toyId;
    if (toyId == null) return const SizedBox.shrink();
    final toy = context.watch<ToyRepository>().toys.firstWhere((t) => t.id == toyId, orElse: () => context.read<ToyRepository>().toys.first);
    final activeCubit = context.watch<ActiveRentalsCubit>();
    final rentals = activeCubit.state.activeRentals.where((r) => r.toyId == toyId).toList();
    final allRentals = context.watch<RentalRepository>().rentals;
    final turnoGross = _turnoGross(allRentals, toyId, session.turnoOpenedAt);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
              color: toy.ink.tint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: TestKeys.exitPostoButton,
                        onPressed: () => context.read<PostoSessionCubit>().exitToSelection(),
                        icon: Icon(Icons.arrow_back, color: toy.ink.fg, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Trocar de posto',
                      ),
                      InitialsAvatar(text: initialsOf(session.monitorName ?? ''), background: toy.ink.dot, foreground: AppColors.bg, size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.monitorName ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: toy.ink.fg),
                        ),
                      ),
                      IconButton(
                        key: TestKeys.closeShiftButton,
                        tooltip: 'Encerrar turno',
                        onPressed: () {
                          context.read<PostoSessionCubit>().beginClosing();
                          Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const CloseShiftView()));
                        },
                        icon: Icon(Icons.receipt_long_outlined, color: toy.ink.fg, size: 19),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(borderRadius: BorderRadius.circular(2), child: const PrintStrip(height: 3)),
                  const SizedBox(height: 10),
                  Text(
                    toy.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600, height: 1.1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${rentals.length} de ${toy.qty} lugares',
                    style: TextStyle(fontSize: 12, color: toy.ink.fg.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rentals.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Ninguém no ${toy.name.toLowerCase()} agora.\nToque em "Colocar criança" pra registrar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.text.withValues(alpha: 0.6)),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      itemCount: rentals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _PostoRentalRow(rental: rentals[i], toy: toy),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => showNewRentalSheet(context, lockedToyId: toyId),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Colocar criança'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent2,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SEU TURNO · ${toy.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 9.5, letterSpacing: 1, fontWeight: FontWeight.w600, color: AppColors.text.withValues(alpha: 0.55)),
                        ),
                        Text(formatMoney(turnoGross), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (session.turnoOpenedAt != null)
                    Text(
                      'desde ${session.turnoOpenedAt!.hour.toString().padLeft(2, '0')}:${session.turnoOpenedAt!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 11, color: AppColors.text.withValues(alpha: 0.55)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bruto do turno = soma do que já foi pago (locações encerradas deste
  /// `toyId` desde que o turno abriu) — mesmo filtro de
  /// `PostoSessionCubit.beginClosing`, recalculado aqui porque o rodapé
  /// de 3b fica ligado o turno inteiro, não só no momento de fechar.
  double _turnoGross(List<Rental> allRentals, String toyId, DateTime? turnoOpenedAt) {
    if (turnoOpenedAt == null) return 0;
    return allRentals
        .where((r) => r.toyId == toyId && r.isCompleted && r.endedAt != null && !r.endedAt!.isBefore(turnoOpenedAt))
        .fold(0.0, (a, r) => a + r.price);
  }
}

/// Mesma fórmula de `ActiveTabView._statusColor` (ported, só esta linha de
/// 3b também precisa — design source artboard 3b mostra o relógio de cada
/// ocupante, não só o valor).
Color _statusColor(double ratio, bool overtime) {
  if (overtime || ratio <= 0.2) return AppColors.statusUrgent;
  if (ratio <= 0.5) return AppColors.statusWarn;
  return AppColors.statusOk;
}

String _fmtClock(double remainMin) {
  final overtime = remainMin < 0;
  final abs = remainMin.abs();
  final mm = abs.floor();
  final ss = ((abs - mm) * 60).round();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${overtime ? '+' : ''}${pad(mm)}:${pad(ss)}';
}

String _fmtElapsed(double elapsedMin) {
  final mm = elapsedMin.floor();
  final ss = ((elapsedMin - mm) * 60).round();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(mm)}:${pad(ss)}';
}

class _PostoRentalRow extends StatelessWidget {
  const _PostoRentalRow({required this.rental, required this.toy});
  final Rental rental;
  final Toy toy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ActiveRentalsCubit>();
    final value = cubit.computeFinalPrice(rental);
    final openEnded = rental.isOpenEnded;
    final elapsedMin = DateTime.now().difference(rental.startedAt).inMilliseconds / 60000;
    final duration = rental.durationMin;
    final remainMin = openEnded ? 0.0 : duration! - elapsedMin;
    final overtime = !openEnded && remainMin < 0;
    final clockColor = openEnded ? AppColors.accent2_700 : _statusColor(remainMin / duration!, overtime);
    final clockText = openEnded ? _fmtElapsed(elapsedMin) : _fmtClock(overtime ? 0.0 : remainMin);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: toy.ink.tint, borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          InitialsAvatar(text: initialsOf(rental.childName), background: toy.ink.dot, foreground: AppColors.bg, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rental.childName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('resp. ${rental.guardianName}', style: TextStyle(fontSize: 11.5, color: AppColors.text.withValues(alpha: 0.65))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                clockText,
                style: TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.w600, color: clockColor),
              ),
              Text(formatMoney(value), style: TextStyle(fontSize: 11, color: AppColors.text.withValues(alpha: 0.65))),
            ],
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            key: TestKeys.finishRentalButton(rental.id),
            onPressed: () => showEndRentalDialog(context, rental.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
  }
}
