import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../test_keys.dart';
import '../theme/app_colors.dart';
import '../ui/features/catalog/views/catalog_view.dart';
import '../ui/features/home/views/home_view.dart';
import '../ui/features/rental/views/active_tab_view.dart';
import '../ui/features/report/views/report_view.dart';
import '../widgets/animations/bounce.dart';
import '../widgets/animations/pressable.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_header.dart';
import '../widgets/modal_launchers.dart';

/// App scaffold: gradient header, tab body, bottom nav and the floating
/// "+" action. The "nova locação" / "finalizar locação" flows are real
/// modal routes (see `modal_launchers.dart`), not a hand-rolled overlay.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final tab = context.select((AppState s) => s.tab);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppHeader(),
      body: switch (tab) {
        AppTab.home => const HomeView(),
        AppTab.active => const ActiveTabView(),
        AppTab.catalog => const CatalogView(),
        AppTab.report => const ReportView(),
      },
      floatingActionButton: Bouncy(
        height: 4,
        period: const Duration(milliseconds: 1200),
        child: Pressable(
          child: FloatingActionButton(
            key: TestKeys.fabNewRental,
            heroTag: 'new-rental-fab',
            backgroundColor: AppColors.accent2,
            foregroundColor: AppColors.bg,
            onPressed: () => showNewRentalSheet(context),
            child: const Icon(Icons.add),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}
