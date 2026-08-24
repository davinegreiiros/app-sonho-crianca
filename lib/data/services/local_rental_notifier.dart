import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'rental_notifier.dart';

/// Real [RentalNotifier]: `flutter_local_notifications`, local only — no
/// server, no push, matching the app's offline baseline (spec
/// 002-seguranca-dados). Uses `AndroidScheduleMode.inexactAllowWhileIdle`
/// on purpose: exact alarms need a separate, more sensitive Android
/// permission (`SCHEDULE_EXACT_ALARM`) that a toy-rental timer doesn't
/// need — being a few minutes off doesn't matter here, and skipping it
/// keeps the permission footprint to just `POST_NOTIFICATIONS`.
class LocalRentalNotifier implements RentalNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'rental_end_channel';
  static const _channelName = 'Fim de locação';
  static const _channelDescription = 'Avisa quando o tempo de uma locação termina';

  @override
  Future<void> init() async {
    if (_initialized) return;
    // A notification that fails to schedule/cancel is never allowed to
    // break the rental flow that triggered it (creating/cancelling/
    // finishing a locação has to succeed regardless of whether the OS or
    // the plugin's platform channel cooperates) — every real call in this
    // class is wrapped the same way, for the same reason.
    try {
      tz_data.initializeTimeZones();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _plugin.initialize(const InitializationSettings(android: androidInit, iOS: iosInit));

      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      _initialized = true;
    } catch (e) {
      // Leaves `_initialized` false — the next schedule/cancel call tries
      // `init()` again instead of silently assuming it's ready. Logged
      // (debug builds only) so a device-validation session (spec 005 T10)
      // can actually see *why* notifications aren't firing instead of a
      // fully silent no-op — this was previously impossible to diagnose.
      debugPrint('LocalRentalNotifier.init failed: $e');
    }
  }

  /// Deterministic positive id from a rental's id (or a derived key —
  /// [scheduleRentalEndingSoon] uses `'${rentalId}_soon'` so both
  /// notifications for the same rental get distinct ids and never
  /// overwrite each other) — lets a later call cancel exactly the
  /// notification that was scheduled, without keeping a separate id map
  /// anywhere.
  int _idFor(String key) => key.hashCode & 0x7fffffff;

  Future<void> _schedule({required int id, required String title, required String body, required DateTime at, required String logLabel}) async {
    await init();
    if (!at.isAfter(DateTime.now())) return; // never schedule into the past

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            // Body carries two lines (spec 009) — without this it can get
            // truncated to one line in the collapsed notification shade.
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // See the comment on `init()` — scheduling failing is never fatal.
      debugPrint('LocalRentalNotifier.$logLabel failed: $e');
    }
  }

  Future<void> _cancel({required int id, required String logLabel}) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      // See the comment on `init()`.
      debugPrint('LocalRentalNotifier.$logLabel failed: $e');
    }
  }

  @override
  Future<void> scheduleRentalEnd({
    required String rentalId,
    required String title,
    required String body,
    required DateTime at,
  }) => _schedule(id: _idFor(rentalId), title: title, body: body, at: at, logLabel: 'scheduleRentalEnd($rentalId)');

  @override
  Future<void> cancelRentalEnd(String rentalId) => _cancel(id: _idFor(rentalId), logLabel: 'cancelRentalEnd($rentalId)');

  @override
  Future<void> scheduleRentalEndingSoon({
    required String rentalId,
    required String title,
    required String body,
    required DateTime at,
  }) => _schedule(id: _idFor('${rentalId}_soon'), title: title, body: body, at: at, logLabel: 'scheduleRentalEndingSoon($rentalId)');

  @override
  Future<void> cancelRentalEndingSoon(String rentalId) =>
      _cancel(id: _idFor('${rentalId}_soon'), logLabel: 'cancelRentalEndingSoon($rentalId)');
}
