import 'package:equatable/equatable.dart';

/// Which body tab `HomeShell` shows — moved from `lib/state/app_state.dart`
/// (spec 021-migracao-shell-app) as-is, no behavior change. `AppState.tab`
/// re-exports this so the ~18 test files that reference `AppTab` via
/// `state/app_state.dart` keep resolving.
enum AppTab { home, active, catalog, report }

/// State emitted by [AppShellCubit] — the app scaffold's own bit of state:
/// which tab is active, plus the cabeçalho's `kicker`/`screenTitle`
/// (computed from [tab] and, for `kicker`, the wall clock at read time —
/// no ticker here, see spec 021's "Dúvidas em aberto": the shell recomputes
/// on navigation, not every second).
class AppShellState extends Equatable {
  const AppShellState({required this.tab});

  final AppTab tab;

  /// Date shown in the header, e.g. "PRAÇA DO PLANALTO · 25/08" — same
  /// format `AppState.kicker` always had.
  String get kicker {
    final dt = DateTime.now();
    String pad2(int n) => n.toString().padLeft(2, '0');
    return 'PRAÇA DO PLANALTO · ${pad2(dt.day)}/${pad2(dt.month)}';
  }

  /// Title shown in the header for the current tab — same mapping
  /// `AppState.screenTitle` always had.
  String get screenTitle => switch (tab) {
        AppTab.home => 'Painel do dia',
        AppTab.active => 'Em andamento',
        AppTab.catalog => 'Brinquedos',
        AppTab.report => 'Faturamento',
      };

  @override
  List<Object?> get props => [tab];
}
