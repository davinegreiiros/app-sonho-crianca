import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_shell_state.dart';

/// ViewModel for the app scaffold (`HomeShell`/`AppBottomNav`/`AppHeader`,
/// spec 021-migracao-shell-app) — no Repository injected, doesn't read
/// domain data, just tracks which tab is active. Last piece of `AppState`
/// still read by a production `View`; after this, `AppState` only serves
/// tests as a setup shortcut (regra de não-quebra).
class AppShellCubit extends Cubit<AppShellState> {
  AppShellCubit() : super(const AppShellState(tab: AppTab.home));

  void setTab(AppTab tab) => emit(AppShellState(tab: tab));
}
