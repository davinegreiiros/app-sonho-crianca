import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../test_keys.dart';
import '../theme/app_colors.dart';
import '../widgets/animations/bounce.dart';
import '../widgets/animations/pressable.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_header.dart';
import '../widgets/modal_launchers.dart';
import 'tabs/active_tab.dart';
import 'tabs/catalog_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/report_tab.dart';

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
        AppTab.home => const HomeTab(),
        AppTab.active => const ActiveTab(),
        AppTab.catalog => const CatalogTab(),
        AppTab.report => const ReportTab(),
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
