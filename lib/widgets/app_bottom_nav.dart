import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../test_keys.dart';
import '../theme/app_colors.dart';
import 'animations/pressable.dart';

/// Custom 4-tab bar: pill-highlighted active tab, matching the design's
/// `tabBg*` / `tabColor*` treatment (not a stock BottomNavigationBar).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  static const _items = [
    (tab: AppTab.home, icon: Icons.home_rounded, label: 'Início', key: TestKeys.navHome),
    (tab: AppTab.active, icon: Icons.timer_rounded, label: 'Ativos', key: TestKeys.navActive),
    (tab: AppTab.catalog, icon: Icons.grid_view_rounded, label: 'Catálogo', key: TestKeys.navCatalog),
    (tab: AppTab.report, icon: Icons.bar_chart_rounded, label: 'Relatório', key: TestKeys.navReport),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.text.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          child: Row(
            children: [
              for (final item in _items)
                Expanded(
                  child: Pressable(
                    child: _NavButton(
                      key: item.key,
                      icon: item.icon,
                      label: item.label,
                      active: state.tab == item.tab,
                      onTap: () => state.setTab(item.tab),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent700 : AppColors.text.withValues(alpha: 0.45);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.accent100 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
