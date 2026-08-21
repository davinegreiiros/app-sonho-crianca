import 'package:sonho_de_crianca/notifications/rental_notifier.dart';

/// Test double for [RentalNotifier]: records calls in memory instead of
/// touching a real platform channel (spec 005-notificacoes-locais).
class FakeRentalNotifier implements RentalNotifier {
  final Map<String, DateTime> scheduled = {};
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
}
