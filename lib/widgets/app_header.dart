import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../test_keys.dart';
import '../theme/app_colors.dart';
import 'animations/bounce.dart';
import 'animations/print_strip.dart';
import 'modal_launchers.dart';

/// Gradient header: CMY logo mark, brand name, location kicker, screen
/// title and the three status dots — ported from the design's header block.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(126);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accent200, AppColors.accent100, AppColors.bg],
          stops: [0, 0.7, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LogoMark(),
              const SizedBox(width: 8),
              const Text(
                'Sonho de Criança',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.01,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.kicker,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1,
                    color: AppColors.text.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                key: TestKeys.settingsGearButton,
                borderRadius: BorderRadius.circular(20),
                onTap: () => showBusinessSettingsSheet(context),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.settings_outlined, size: 18, color: AppColors.text.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _CmyStrip(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.screenTitle,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                  height: 1.05,
                ),
              ),
              const Row(
                children: [
                  Bouncy(phase: 0, child: _Dot(AppColors.accent)),
                  SizedBox(width: 4),
                  Bouncy(phase: 0.33, child: _Dot(AppColors.accent2)),
                  SizedBox(width: 4),
                  Bouncy(phase: 0.66, child: _Dot(AppColors.processYellow)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.logoPink,
            AppColors.logoOrange,
            AppColors.logoYellow,
          ],
        ),
      ),
      child: const Center(
        child: Text(
          'SC',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _CmyStrip extends StatelessWidget {
  const _CmyStrip();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        PrintStrip(height: 3),
        SizedBox(height: 0),
        Divider(height: 1, thickness: 1, color: AppColors.divider),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
