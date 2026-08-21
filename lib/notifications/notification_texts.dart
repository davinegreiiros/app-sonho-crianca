/// Every notification string the app sends lives here — one place to
/// adjust wording without touching scheduling logic (spec
/// 005-notificacoes-locais).
library;

/// Title + body for "this rental's time is up". Shows the toy and the
/// child's name (decision registered in the spec/002-seguranca-dados —
/// guardian name/phone never appear here, only the toy and child).
(String title, String body) rentalEndedNotificationText({
  required String childName,
  required String toyName,
}) {
  return ('$childName · $toyName', 'Tempo esgotado — hora de finalizar a locação.');
}
