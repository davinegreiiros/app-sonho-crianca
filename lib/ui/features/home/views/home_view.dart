import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/formatters.dart';
import '../../../../domain/models/rental.dart';
import '../../../../test_keys.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/animations/cascade.dart';
import '../../../../widgets/animations/confetti.dart';
import '../../../../widgets/animations/pressable.dart';
import '../../../../widgets/modal_launchers.dart';
import '../../../../widgets/toy_icon.dart';
import '../view_models/home_cubit.dart';
import '../view_models/home_state.dart';

/// Migrated in spec 019-migracao-painel-home: reads through [HomeCubit]
/// instead of `AppState` — the last screen to migrate off it.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  CascadeController? _cascade;
  int _lastItemCount = -1;

  @override
  void dispose() {
    _cascade?.dispose();
    super.dispose();
  }

  /// 3 fixed sections (total card, stats row, recent-activity block) plus
  /// one slot per recent-activity row. Re-armed only when the row count
  /// changes, so the 1s countdown ticker doesn't replay it every second.
  CascadeController _cascadeFor(int recentCount) {
    final itemCount = 3 + recentCount;
    if (_cascade == null || _lastItemCount != itemCount) {
      _cascade?.dispose();
      _cascade = CascadeController(this, itemCount: itemCount);
      _lastItemCount = itemCount;
    }
    return _cascade!;
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeCubit>().state;
    final recent = home.recentActivity;
    final cascade = _cascadeFor(recent.length);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
      children: [
        cascade.item(0, child: _TotalTodayCard(home: home)),
        const SizedBox(height: 20),
        cascade.item(
          1,
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  bg: AppColors.accent2_200,
                  labelColor: AppColors.accent2_700,
                  valueColor: AppColors.accent2_900,
                  label: 'Agora',
                  value: '${home.activeCount}',
                  caption: 'em uso na praça',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  bg: AppColors.yellowTint,
                  labelColor: AppColors.yellowFg,
                  valueColor: AppColors.yellowFgDark,
                  label: 'Disponíveis',
                  value: '${home.availableCount}',
                  caption: 'prontas pra locar',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: Pressable(
            child: ElevatedButton.icon(
              key: TestKeys.homeNewRentalButton,
              onPressed: () => showNewRentalSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                elevation: 0,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nova locação'),
            ),
          ),
        ),
        const SizedBox(height: 20),
        cascade.item(
          2,
          child: Container(
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Text(
                    'ATIVIDADE RECENTE',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nenhuma atividade ainda hoje.',
                      style: TextStyle(fontSize: 13, color: AppColors.text.withValues(alpha: 0.6)),
                    ),
                  )
                else
                  for (var i = 0; i < recent.length; i++)
                    cascade.item(3 + i, child: _ActivityRow(home: home, rental: recent[i])),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalTodayCard extends StatelessWidget {
  const _TotalTodayCard({required this.home});
  final HomeState home;

  @override
  Widget build(BuildContext context) {
    final count = home.doneTodayCount;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        color: AppColors.accent100,
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Positioned(
              top: -14,
              right: -14,
              child: _bubble(64, AppColors.accent.withValues(alpha: 0.18)),
            ),
            Positioned(
              top: 34,
              right: 34,
              child: _bubble(20, AppColors.accent2.withValues(alpha: 0.22)),
            ),
            Positioned(
              bottom: -10,
              right: 52,
              child: _bubble(34, AppColors.processYellow.withValues(alpha: 0.3)),
            ),
            const Positioned.fill(child: FloatingConfetti()),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FATURADO HOJE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent700,
                  ),
                ),
                Text(
                  formatMoney(home.homeTotalToday),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: AppColors.accent900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count ${count == 1 ? 'locação finalizada' : 'locações finalizadas'} hoje',
                  style: TextStyle(fontSize: 12.5, color: AppColors.accent900.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.bg,
    required this.labelColor,
    required this.valueColor,
    required this.label,
    required this.value,
    required this.caption,
  });

  final Color bg;
  final Color labelColor;
  final Color valueColor;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600, color: labelColor)),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: valueColor)),
          Text(caption, style: TextStyle(fontSize: 11.5, color: valueColor.withValues(alpha: 0.65))),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.home, required this.rental});
  final HomeState home;
  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final toy = home.toyById(rental.toyId);
    final active = rental.status == RentalStatus.active;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.text.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: toy.ink.tint, borderRadius: BorderRadius.circular(4)),
            child: ToyIcon(imageKey: toy.imageKey, ink: toy.ink, size: 32, radius: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${toy.name} · ${rental.childName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  active ? 'em andamento' : formatRelativeTime(rental.endedAt!),
                  style: TextStyle(fontSize: 12, color: AppColors.text.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          Text(
            formatMoney(rental.price),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.accent700 : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
