import '../formatters.dart';
import '../models/rental.dart';
import '../models/toy.dart';
import '../notification_texts.dart';
import '../rental_notifier.dart';

/// Schedules the two notifications a fixed-duration rental gets (specs
/// 005-notificacoes-locais + 009-notificacao-formato-aviso-previo):
/// "time's up" and the "5 minutes left" heads-up. No-op for an
/// open-ended ("tempo corrido", spec 006) rental — it has no fixed end
/// time to notify about.
///
/// Extracted out of `AppState._scheduleEndNotification` (spec
/// 017-migracao-nova-locacao) so `NewRentalCubit` doesn't duplicate it —
/// first Use Case in this codebase reused by more than one caller.
class ScheduleRentalEndNotifications {
  const ScheduleRentalEndNotifications();

  void call(Rental rental, Toy toy, RentalNotifier notifier) {
    if (rental.isOpenEnded) return;
    final endsAt = rental.startedAt.add(Duration(minutes: rental.durationMin!));

    final (endTitle, endBody) = rentalEndedNotificationText(
      childName: rental.childName,
      toyName: toy.name,
      durationMin: rental.durationMin!,
      priceFormatted: formatMoney(rental.price),
    );
    notifier.scheduleRentalEnd(rentalId: rental.id, title: endTitle, body: endBody, at: endsAt);

    final (soonTitle, soonBody) = rentalEndingSoonNotificationText(
      childName: rental.childName,
      toyName: toy.name,
      endsAt: endsAt,
    );
    notifier.scheduleRentalEndingSoon(
      rentalId: rental.id,
      title: soonTitle,
      body: soonBody,
      at: endsAt.subtract(const Duration(minutes: 5)),
    );
  }
}
