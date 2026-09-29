// Pure, Flutter-independent formatters shared across layers — extracted
// out of `AppState` (`fmtMoney`/`whenLabel`, unchanged behavior, spec
// 014-migracao-relatorio) so `ReportCubit` didn't have to duplicate them.
// Lives in `lib/domain/` (not `lib/ui/core/`, where it started) since
// spec 017-migracao-nova-locacao: `ScheduleRentalEndNotifications`, a
// `domain/use_cases/` Use Case, needs `formatMoney` too, and the domain
// layer can't import from `lib/ui/`.

/// `R$ 12,50`-style money label — always 2 decimals, comma as the
/// decimal separator (pt-BR).
String formatMoney(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

/// Coarse "há N min/h/d" relative-time label (spec 001's original design
/// language) — not locale-aware, matches the app's single pt-BR audience.
String formatRelativeTime(DateTime timestamp) {
  final minutes = DateTime.now().difference(timestamp).inSeconds / 60;
  if (minutes < 60) return 'há ${(minutes < 1 ? 1 : minutes.round())} min';
  final hours = minutes / 60;
  if (hours < 24) return 'há ${hours.round()}h';
  return 'há ${(hours / 24).round()}d';
}
