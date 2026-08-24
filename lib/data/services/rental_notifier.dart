/// Minimal seam between `AppState` and however "schedule a notification
/// for when a rental's time is up" actually happens — spec
/// 005-notificacoes-locais. Exists so tests can swap in a fake that
/// records calls instead of hitting a real platform channel (there's no
/// real notification plugin available under `flutter test`).
abstract class RentalNotifier {
  /// Sets up whatever the real implementation needs (channel, permission)
  /// — safe to call more than once, and safe to leave until the first
  /// real [scheduleRentalEnd] call (spec: permission asked lazily, not at
  /// app boot).
  Future<void> init();

  /// Schedules a "this rental's time is up" notification for [at]. A
  /// second call for the same [rentalId] replaces the first — callers
  /// don't need to cancel before rescheduling.
  Future<void> scheduleRentalEnd({
    required String rentalId,
    required String title,
    required String body,
    required DateTime at,
  });

  /// Cancels a previously scheduled notification for [rentalId], if any.
  /// A no-op if none was scheduled — cancelling something that was
  /// already cancelled, finished, or never scheduled (tempo corrido, spec
  /// 006) is never an error.
  Future<void> cancelRentalEnd(String rentalId);

  /// Schedules the "5 minutes left" heads-up for [at] (spec
  /// 009-notificacao-formato-aviso-previo) — a separate notification from
  /// [scheduleRentalEnd], for the same [rentalId]. A second call for the
  /// same [rentalId] replaces the first, same as [scheduleRentalEnd].
  Future<void> scheduleRentalEndingSoon({
    required String rentalId,
    required String title,
    required String body,
    required DateTime at,
  });

  /// Cancels a previously scheduled "5 minutes left" notification for
  /// [rentalId], if any — independent from [cancelRentalEnd], since both
  /// notifications exist for the same rental at once. A no-op if none was
  /// scheduled.
  Future<void> cancelRentalEndingSoon(String rentalId);
}
