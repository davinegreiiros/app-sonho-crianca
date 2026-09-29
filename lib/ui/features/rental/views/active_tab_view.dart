import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/formatters.dart';
import '../../../../domain/models/rental.dart';
import '../../../../test_keys.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/animations/cascade.dart';
import '../../../../widgets/animations/endless_rail.dart';
import '../../../../widgets/animations/pressable.dart';
import '../../../../widgets/animations/pulse.dart';
import '../../../../widgets/animations/striped_progress.dart';
import '../../../../widgets/modal_launchers.dart';
import '../../../../widgets/toy_icon.dart';
import '../view_models/active_rentals_cubit.dart';

/// Migrated in spec 018-migracao-locacao-ativa-encerrar: reads/writes
/// through [ActiveRentalsCubit] instead of `AppState`.
class ActiveTabView extends StatefulWidget {
  const ActiveTabView({super.key});

  @override
  State<ActiveTabView> createState() => _ActiveTabViewState();
}

class _ActiveTabViewState extends State<ActiveTabView> with TickerProviderStateMixin {
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
    final cubit = context.watch<ActiveRentalsCubit>();
    final rentals = cubit.state.activeRentals;

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
      itemBuilder: (context, i) => cascade.item(i, child: _ActiveCard(cubit: cubit, rental: rentals[i])),
    );
  }
}

/// Overtime uses the alert color regardless of ratio; otherwise a
/// green/amber/red gradient by how much time is left — ported unchanged
/// from `AppState.statusColor` (only this screen ever called it).
Color _statusColor(double ratio, bool overtime) {
  if (overtime || ratio <= 0.2) return AppColors.statusUrgent;
  if (ratio <= 0.5) return AppColors.statusWarn;
  return AppColors.statusOk;
}

/// `+MM:SS`/`MM:SS` countdown label, ported unchanged from
/// `AppState.fmtClock` (only this screen ever called it).
String _fmtClock(double remainMin) {
  final overtime = remainMin < 0;
  final abs = remainMin.abs();
  final mm = abs.floor();
  final ss = ((abs - mm) * 60).round();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${overtime ? '+' : ''}${pad(mm)}:${pad(ss)}';
}

/// Always on — was a fixed `AppState._pulseOnOvertime` design-time flag,
/// never toggled; kept as a named constant here for the same readability
/// it gave `StripedProgress(..., pulse: overtime && _pulseOnOvertime)`.
const _pulseOnOvertime = true;

/// "Estimado agora" block for a tempo-corrido card: the running total in
/// large type plus elapsed minutes and a reminder that the final charge
/// only locks in when the operator taps "Parar e cobrar" (design source:
/// `specs/007-revisao-design-v3`, artboard 1e).
class _EstimateNow extends StatelessWidget {
  const _EstimateNow({required this.value, required this.elapsedMin});
  final double value;
  final double elapsedMin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(color: AppColors.bg.withValues(alpha: 0.62), borderRadius: BorderRadius.circular(3)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESTIMADO AGORA',
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text.withValues(alpha: 0.55),
                  ),
                ),
                Text(formatMoney(value), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.1)),
              ],
            ),
          ),
          Text(
            '${elapsedMin.floor()} min\nfecha no botão',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.text.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

/// "Tempo corrido" badge styled like a punched ticket stub — two small
/// notches on its left/right edges, colored like the card behind it, so
/// it reads as a canhoto picotado rather than a plain pill (design
/// source: `specs/007-revisao-design-v3`, artboard 1e bullet list).
class _CanhotoBadge extends StatelessWidget {
  const _CanhotoBadge({required this.cardColor, required this.fg});
  final Color cardColor;
  final Color fg;

  static const _notch = 7.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: AppColors.bg.withValues(alpha: 0.78), borderRadius: BorderRadius.circular(1.5)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.all_inclusive_rounded, size: 12, color: fg),
              const SizedBox(width: 5),
              Text(
                'TEMPO CORRIDO',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: fg),
              ),
            ],
          ),
        ),
        Positioned(
          left: -_notch / 2,
          top: 0,
          bottom: 0,
          child: Center(child: _notchDot()),
        ),
        Positioned(
          right: -_notch / 2,
          top: 0,
          bottom: 0,
          child: Center(child: _notchDot()),
        ),
      ],
    );
  }

  Widget _notchDot() => Container(width: _notch, height: _notch, decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle));
}

/// "+ tempo" chip row for a fixed-duration active rental (spec 008):
/// 5/10/15 min presets, each calling [ActiveRentalsCubit.extendActive].
/// Never shown for "tempo corrido" (spec 006) rentals, which have no
/// duration to extend.
class _ExtendTimeRow extends StatelessWidget {
  const _ExtendTimeRow({required this.cubit, required this.rentalId, required this.fg});
  final ActiveRentalsCubit cubit;
  final String rentalId;
  final Color fg;

  static const _presets = [5, 10, 15];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.add_alarm_rounded, size: 14, color: fg.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text('+ tempo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg.withValues(alpha: 0.7))),
        const SizedBox(width: 8),
        for (final m in _presets) ...[
          Pressable(
            child: OutlinedButton(
              key: TestKeys.extendRentalButton(rentalId, m),
              onPressed: () => cubit.extendActive(rentalId, m),
              style: OutlinedButton.styleFrom(
                foregroundColor: fg,
                side: BorderSide(color: fg.withValues(alpha: 0.25)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              child: Text('+$m'),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
  }
}

/// Plain MM:SS of elapsed time, counting up — no `+`/overtime sign, since
/// a "tempo corrido" rental (spec 006) has no target it can run over.
String _fmtElapsed(double elapsedMin) {
  final mm = elapsedMin.floor();
  final ss = ((elapsedMin - mm) * 60).round();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(mm)}:${pad(ss)}';
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.cubit, required this.rental});
  final ActiveRentalsCubit cubit;
  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final toy = cubit.toyById(rental.toyId);
    final elapsedMin = DateTime.now().difference(rental.startedAt).inMilliseconds / 60000;

    // "Tempo corrido" (spec 006) has no fixed duration, so none of the
    // countdown/overtime/progress math below applies to it — no remaining
    // time, no ratio, no urgency color, no percent-complete bar.
    final openEnded = rental.isOpenEnded;
    final duration = rental.durationMin;
    final remainMin = openEnded ? 0.0 : duration! - elapsedMin;
    final overtime = !openEnded && remainMin < 0;
    // Tempo corrido (spec 006) reads in magenta, not the fixed rental's
    // green/amber/red status colors — it never has an "urgency" state to
    // signal (design source, artboard 1e).
    final color = openEnded ? AppColors.accent2_700 : _statusColor(remainMin / duration!, overtime);
    final progress = openEnded ? 0.0 : (elapsedMin / duration!).clamp(0.0, 1.0);
    final liveValue = openEnded ? cubit.computeFinalPrice(rental) : rental.price;
    final rate = openEnded ? (rental.ratePerMinute ?? cubit.ratePerMinute(toy)) : 0.0;

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
                    openEnded
                        ? _CanhotoBadge(cardColor: toy.ink.tint, fg: toy.ink.fg)
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.bg.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              '$duration min',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: toy.ink.fg),
                            ),
                          ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Overtime alarm (spec 008, amended 2026-08-22 per product
                  // owner decision): once time's up the clock freezes at
                  // 00:00 below instead of counting up past it, and this
                  // blinking "TEMPO ESGOTADO" label is the reinforcement —
                  // stronger and more explicit than the red color/pulsing
                  // `StripedProgress` alone. No sound, per the original
                  // spec 008 decision.
                  if (overtime) ...[
                    Pulse(
                      minOpacity: 0.15,
                      period: const Duration(milliseconds: 700),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_rounded, size: 12, color: color),
                          const SizedBox(width: 3),
                          Text(
                            'TEMPO ESGOTADO',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: color),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (openEnded) ...[
                        Pulse(
                          child: Icon(Icons.keyboard_arrow_up_rounded, size: 14, color: color),
                        ),
                        const SizedBox(width: 2),
                      ],
                      Text(
                        openEnded ? _fmtElapsed(elapsedMin) : _fmtClock(overtime ? 0.0 : remainMin),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    openEnded ? '${formatMoney(rate)}/min' : formatMoney(liveValue),
                    style: TextStyle(fontSize: 11, color: AppColors.text.withValues(alpha: 0.65)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (openEnded) ...[
            _EstimateNow(value: liveValue, elapsedMin: elapsedMin),
            const SizedBox(height: 10),
            EndlessRail(color: color),
            const SizedBox(height: 8),
          ] else ...[
            StripedProgress(progress: progress, color: color, pulse: overtime && _pulseOnOvertime),
            const SizedBox(height: 8),
            _ExtendTimeRow(cubit: cubit, rentalId: rental.id, fg: toy.ink.fg),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Pressable(
                  child: OutlinedButton(
                    key: TestKeys.cancelRentalButton(rental.id),
                    onPressed: () => cubit.cancelActive(rental.id),
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
                    child: Text(openEnded ? 'Parar e cobrar' : 'Finalizar'),
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
