import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/rental.dart';
import '../../state/app_state.dart';
import '../../test_keys.dart';
import '../../theme/app_colors.dart';
import '../../widgets/animations/cascade.dart';
import '../../widgets/animations/pressable.dart';
import '../../widgets/animations/striped_progress.dart';
import '../../widgets/modal_launchers.dart';
import '../../widgets/toy_icon.dart';

class ActiveTab extends StatefulWidget {
  const ActiveTab({super.key});

  @override
  State<ActiveTab> createState() => _ActiveTabState();
}

class _ActiveTabState extends State<ActiveTab> with TickerProviderStateMixin {
  CascadeController? _cascade;
  int _lastCount = -1;

  CascadeController _cascadeFor(int count) {
    if (_cascade == null || _lastCount != count) {
      _cascade?.dispose();
      _cascade = CascadeController(this, itemCount: count);
      _lastCount = count;
    }
    return _cascade!;
  }

  @override
  void dispose() {
    _cascade?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rentals = state.activeRentals;

    if (rentals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Nenhum brinquedo em uso agora.\nToque em "+" pra registrar uma locação.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.text.withValues(alpha: 0.6)),
          ),
        ),
      );
    }

    final cascade = _cascadeFor(rentals.length);

    return ListView.separated(
      // Scaffold's floatingActionButton already reserves clearance above
      // the bottom nav; this extra padding keeps the last card's buttons
      // comfortably clear of the FAB too.
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
      itemCount: rentals.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, i) => cascade.item(i, child: _ActiveCard(state: state, rental: rentals[i])),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.state, required this.rental});
  final AppState state;
  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final toy = state.toyById(rental.toyId);
    final elapsedMin = DateTime.now().difference(rental.startedAt).inMilliseconds / 60000;
    final remainMin = rental.durationMin - elapsedMin;
    final ratio = remainMin / rental.durationMin;
    final overtime = remainMin < 0;
    final color = state.statusColor(ratio, overtime);
    final progress = (elapsedMin / rental.durationMin).clamp(0.0, 1.0);

    return Container(
      key: TestKeys.activeCardKey(rental.id),
      decoration: BoxDecoration(color: toy.ink.tint, borderRadius: BorderRadius.circular(4)),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ToyIcon(imageKey: toy.imageKey, ink: toy.ink, size: 56, radius: 3),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(toy.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(
                      '${rental.childName} · resp. ${rental.guardianName}',
                      style: TextStyle(fontSize: 12, color: AppColors.text.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.bg.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '${rental.durationMin} min',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: toy.ink.fg),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    state.fmtClock(remainMin),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    state.fmtMoney(rental.price),
                    style: TextStyle(fontSize: 11, color: AppColors.text.withValues(alpha: 0.65)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          StripedProgress(progress: progress, color: color, pulse: overtime && state.pulseOnOvertime),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  child: OutlinedButton(
                    key: TestKeys.cancelRentalButton(rental.id),
                    onPressed: () => state.cancelActive(rental.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: BorderSide(color: AppColors.text.withValues(alpha: 0.14)),
                      backgroundColor: AppColors.bg.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Pressable(
                  child: ElevatedButton(
                    key: TestKeys.finishRentalButton(rental.id),
                    onPressed: () => showEndRentalDialog(context, rental.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.bg,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Finalizar'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
