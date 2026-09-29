import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/rental_repository.dart';
import '../../../../data/repositories/toy_repository.dart';
import '../../../../domain/formatters.dart';
import '../../../../domain/models/rental.dart';
import '../../../../test_keys.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/modal_launchers.dart';
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              color: toy.ink.tint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: TestKeys.exitPostoButton,
                        onPressed: () => context.read<PostoSessionCubit>().exitToSelection(),
                        icon: Icon(Icons.arrow_back, color: toy.ink.fg, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Text(
                          session.monitorName ?? '',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: toy.ink.fg),
                        ),
                      ),
                      TextButton(
                        key: TestKeys.closeShiftButton,
                        onPressed: () {
                          context.read<PostoSessionCubit>().beginClosing();
                          Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const CloseShiftView()));
                        },
                        child: Text('Encerrar turno', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: toy.ink.fg)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(toy.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.05)),
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
                      itemBuilder: (context, i) => _PostoRentalRow(rental: rentals[i]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                        Text('SEU TURNO', style: TextStyle(fontSize: 9.5, letterSpacing: 1, fontWeight: FontWeight.w600, color: AppColors.text.withValues(alpha: 0.55))),
                        Text(formatMoney(turnoGross), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600)),
                      ],
                    ),
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
        .where((r) => r.toyId == toyId && r.status == RentalStatus.done && r.endedAt != null && !r.endedAt!.isBefore(turnoOpenedAt))
        .fold(0.0, (a, r) => a + r.price);
  }
}

class _PostoRentalRow extends StatelessWidget {
  const _PostoRentalRow({required this.rental});
  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ActiveRentalsCubit>();
    final value = cubit.computeFinalPrice(rental);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rental.childName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('resp. ${rental.guardianName}', style: TextStyle(fontSize: 11.5, color: AppColors.text.withValues(alpha: 0.65))),
              ],
            ),
          ),
          Text(formatMoney(value), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
