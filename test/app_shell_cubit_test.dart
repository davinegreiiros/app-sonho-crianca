// Tests for spec 021 (migração — shell do app): AppShellCubit tracks the
// active tab and derives kicker/screenTitle from it, no ticker (kicker only
// recomputes on setTab, see spec.md "Dúvidas em aberto").

import 'package:flutter_test/flutter_test.dart';

import 'package:sonho_de_crianca/ui/features/app_shell/view_models/app_shell_cubit.dart';
import 'package:sonho_de_crianca/ui/features/app_shell/view_models/app_shell_state.dart';

void main() {
  group('AppShellCubit', () {
    test('initial state is AppTab.home', () {
      final cubit = AppShellCubit();

      expect(cubit.state.tab, AppTab.home);

      cubit.close();
    });

    test('setTab emits the new tab', () {
      final cubit = AppShellCubit();

      cubit.setTab(AppTab.catalog);

      expect(cubit.state.tab, AppTab.catalog);

      cubit.close();
    });

    test('screenTitle matches the active tab', () {
      final cubit = AppShellCubit();

      expect(cubit.state.screenTitle, 'Painel do dia');

      cubit.setTab(AppTab.active);
      expect(cubit.state.screenTitle, 'Em andamento');

      cubit.setTab(AppTab.catalog);
      expect(cubit.state.screenTitle, 'Brinquedos');

      cubit.setTab(AppTab.report);
      expect(cubit.state.screenTitle, 'Faturamento');

      cubit.close();
    });

    test('kicker includes today\'s day/month', () {
      final cubit = AppShellCubit();
      final now = DateTime.now();
      final expectedDay = now.day.toString().padLeft(2, '0');
      final expectedMonth = now.month.toString().padLeft(2, '0');

      expect(cubit.state.kicker, contains('$expectedDay/$expectedMonth'));

      cubit.close();
    });
  });
}
