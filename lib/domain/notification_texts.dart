/// Every notification string the app sends lives here — one place to
/// adjust wording without touching scheduling logic (spec
/// 005-notificacoes-locais, reformatted by spec
/// 009-notificacao-formato-aviso-previo).
library;

String _pad2(int n) => n.toString().padLeft(2, '0');

/// Title + body for "this rental's time is up" (spec 005; reformatted by
/// spec 009 to show duration and the amount to charge, so the operator
/// can act on the notification without opening the app first). Shows the
/// toy and the child's name (decision registered in spec/002-seguranca-
/// dados — guardian name/phone never appear here).
(String title, String body) rentalEndedNotificationText({
  required String childName,
  required String toyName,
  required int durationMin,
  required String priceFormatted,
}) {
  return ('Tempo esgotado · $childName', '$toyName · $durationMin min\n$priceFormatted a receber — toque para cobrar');
}

/// Title + body for the "5 minutes left" heads-up (spec 009) — sent
/// before the rental's time actually runs out, so the operator has a
/// chance to warn the guardian in advance. [endsAt] is the rental's exact
/// end time (`startedAt + durationMin`), shown as `HH:mm`.
(String title, String body) rentalEndingSoonNotificationText({
  required String childName,
  required String toyName,
  required DateTime endsAt,
}) {
  final time = '${_pad2(endsAt.hour)}:${_pad2(endsAt.minute)}';
  return ('Faltam 5 min · $childName', '$toyName · encerra $time — já pode avisar o responsável');
}
