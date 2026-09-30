import 'package:sonho_de_crianca/domain/rental_notifier.dart';

/// Test double for [RentalNotifier]: records calls in memory instead of
/// touching a real platform channel (spec 005-notificacoes-locais, spec
/// 009-notificacao-formato-aviso-previo). `scheduled` tracks the "time's
/// up" notification, `scheduledEndingSoon` tracks the separate "5
/// minutes left" one — same rental can have both at once.
class FakeRentalNotifier implements RentalNotifier {
  final Map<String, DateTime> scheduled = {};
  final Map<String, DateTime> scheduledEndingSoon = {};
  int initCalls = 0;

  @override
  Future<void> init() async {
    initCalls++;
  }

  @override
  Future<void> scheduleRentalEnd({
    required String rentalId,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    scheduled[rentalId] = at;
  }

  @override
  Future<void> cancelRentalEnd(String rentalId) async {
    scheduled.remove(rentalId);
  }

  @override
  Future<void> scheduleRentalEndingSoon({
    required String rentalId,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    // Mirrors `LocalRentalNotifier`'s "never schedule into the past" guard
    // — a rental with 5min or less has nothing left to warn about by the
    // time it's created.
    if (!at.isAfter(DateTime.now())) return;
    scheduledEndingSoon[rentalId] = at;
  }

  @override
  Future<void> cancelRentalEndingSoon(String rentalId) async {
    scheduledEndingSoon.remove(rentalId);
  }
}
