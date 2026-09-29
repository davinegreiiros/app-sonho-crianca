import 'dart:async';
import 'package:flutter/material.dart';

import '../data/repositories/business_settings_repository.dart';
import '../data/repositories/rental_repository.dart';
import '../data/repositories/toy_repository.dart';
import '../data/services/local_rental_notifier.dart';
import '../domain/formatters.dart';
import '../domain/models/business_settings.dart';
import '../domain/models/rental.dart';
import '../domain/models/toy.dart';
import '../domain/rental_notifier.dart';
import '../domain/use_cases/schedule_rental_end_notifications.dart';
import '../theme/app_colors.dart';
import '../ui/features/app_shell/view_models/app_shell_state.dart';

export '../ui/features/app_shell/view_models/app_shell_state.dart' show AppTab;

/// Draft form state for the "Nova locação" sheet.
class RentalDraft {
  RentalDraft({
    required this.toyId,
    this.childName = '',
    this.guardianName = '',
    this.guardianPhone = '',
    required this.durationMin,
    required this.price,
  });

  String toyId;
  String childName;
  String guardianName;
  String guardianPhone;
  int durationMin;
  double price;

  /// "Tempo corrido" (spec 006): no fixed duration, price computed from
  /// elapsed time when the rental is finished. When `true`, [durationMin]/
  /// [price] above are still kept in sync with the current toy (so no
  /// non-nullable field goes stale) but the UI doesn't show or use them.
  bool openEnded = false;

  /// Operator-chosen R$/min for a tempo-corrido rental — `null` means "use
  /// the toy's own price/blockMin rate", the pre-filled suggestion. Reset
  /// whenever the toy changes ([AppState.setDraftToy]), since a rate
  /// typed for one toy isn't meant to carry over to a different one.
  double? customRatePerMinute;
}

/// Central app state, ported from the original `.dc.html` Component logic:
/// toy catalog, rentals (active + history), the "nova locação" draft, the
/// end-rental flow, and the report period filter. A 1s ticker keeps active
/// rental countdowns live.
class AppState extends ChangeNotifier {
  AppState({
    RentalNotifier? notifications,
    BusinessSettingsRepository? businessSettingsRepository,
    ToyRepository? toyRepository,
    RentalRepository? rentalRepository,
  })  : notifications = notifications ?? LocalRentalNotifier(),
        _businessSettingsRepository = businessSettingsRepository ?? BusinessSettingsRepository(),
        _ownsBusinessSettingsRepository = businessSettingsRepository == null,
        _toyRepository = toyRepository ?? ToyRepository(),
        _ownsToyRepository = toyRepository == null,
        _rentalRepository = rentalRepository ?? RentalRepository(),
        _ownsRentalRepository = rentalRepository == null {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    // BusinessSettings ownership moved to BusinessSettingsRepository (spec
    // 011-migracao-configuracoes-negocio) — AppState only relays its
    // changes so end_rental_dialog.dart/pix_qr_sheet.dart (not migrated
    // yet, fatia 017+) keep working unchanged off `businessSettings` below.
    // `load()` (dos 3 Repositories) não é mais disparado daqui (spec
    // 020-persistencia-local) — vira responsabilidade explícita de
    // `main.dart`, aguardado antes do primeiro frame (sem isso, o boot
    // "piscaria" Catálogo/Painel vazios até o load assíncrono resolver).
    _businessSettingsRepository.addListener(notifyListeners);
    // Toy ownership moved to ToyRepository (spec
    // 012-migracao-catalogo-criacao) — same relay pattern, needed by
    // every other tab/sheet that reads `toys`/`toyById` and hasn't
    // migrated yet. ToyRepository seeds itself synchronously (no
    // SharedPreferences involved), so `_seed()` below can rely on `toys`
    // already being populated.
    _toyRepository.addListener(notifyListeners);
    // Rental ownership moved to RentalRepository (spec
    // 013-migracao-rental-repository-fundacao) — same relay pattern.
    // RentalRepository seeds itself synchronously, so `_seed()` below
    // (which only sets up `draft` now) can rely on `rentals` already
    // being populated.
    _rentalRepository.addListener(notifyListeners);
    _seed();
    // Permission asked right at boot, not lazily on first rental (spec
    // 005 amendment, 2026-08-22, product owner decision) — fire-and-forget:
    // `init()` is idempotent and swallows its own errors (see
    // `LocalRentalNotifier`), so it never delays or blocks app startup.
    this.notifications.init();
  }

  /// Schedules/cancels "this rental's time is up" notifications (spec
  /// 005-notificacoes-locais). Injectable so tests can swap in a fake
  /// instead of hitting a real platform channel — see `RentalNotifier`.
  final RentalNotifier notifications;

  /// Single source of truth for `BusinessSettings` (spec
  /// 011-migracao-configuracoes-negocio) — shared with
  /// `BusinessSettingsCubit` in production (wired in `main.dart`); tests
  /// that don't pass one get their own default instance, same pattern as
  /// [notifications]/`LocalRentalNotifier`.
  final BusinessSettingsRepository _businessSettingsRepository;

  /// Whether this `AppState` created its own default
  /// [_businessSettingsRepository] (no shared instance was injected) —
  /// only then does [dispose] also dispose the repository; a shared
  /// instance (e.g. wired in `main.dart` alongside `BusinessSettingsCubit`)
  /// outlives any single `AppState` and is disposed by whoever created it.
  final bool _ownsBusinessSettingsRepository;

  /// Single source of truth for the toy catalog (spec
  /// 012-migracao-catalogo-criacao) — shared with `ToyCatalogCubit` in
  /// production (wired in `main.dart`); same opt-in pattern as
  /// [_businessSettingsRepository].
  final ToyRepository _toyRepository;
  final bool _ownsToyRepository;

  /// Single source of truth for the rental list (spec
  /// 013-migracao-rental-repository-fundacao) — foundation only, no Cubit
  /// consumes it yet (that starts at fatia 014). Same opt-in pattern as
  /// [_businessSettingsRepository]/[_toyRepository].
  final RentalRepository _rentalRepository;
  final bool _ownsRentalRepository;

  BusinessSettings get businessSettings => _businessSettingsRepository.settings;

  Future<void> updateBusinessSettings({
    required String merchantName,
    required String merchantCity,
    required String pixKey,
  }) {
    return _businessSettingsRepository.update(
      BusinessSettings(merchantName: merchantName, merchantCity: merchantCity, pixKey: pixKey),
    );
  }

  late final Timer _ticker;

  AppTab tab = AppTab.home;
  List<Toy> get toys => _toyRepository.toys;
  List<Rental> get rentals => _rentalRepository.rentals;

  bool showNew = false;
  late RentalDraft draft;

  String? endingId;
  PaymentMethod? endPayment;

  /// Whether the "Finalizar locação" dialog is showing the Pix QR step
  /// (spec 004-pix-qrcode) instead of the payment-method picker — same
  /// dialog route, different content, so it never races with
  /// [closeEnd]'s reset of [endingId]/[endPayment].
  bool endShowPixQr = false;

  /// Price frozen the instant the Pix QR step opens ([showPixQrStep]) —
  /// for a tempo-corrido (spec 006) rental, [computeFinalPrice] keeps
  /// climbing every second the QR stays on screen, so recomputing it
  /// again in [confirmEnd] once the customer finally pays would charge
  /// more than the amount actually encoded in the QR they scanned. `null`
  /// outside the Pix QR step (Cartão/Dinheiro confirm at the price shown
  /// there and then, no QR-wait window to freeze against).
  double? endFrozenPrice;

  void _seed() {
    // Toys are seeded by ToyRepository, rentals by RentalRepository
    // (specs 012/013) — nothing to do here anymore beyond the draft,
    // which depends on both being already populated (see the
    // repository-listener setup above, run before this call).
    final first = toys.firstWhere((t) => toyAvailable(t) > 0, orElse: () => toys.first);
    draft = RentalDraft(toyId: first.id, durationMin: first.blockMin, price: first.price);
  }

  @override
  void dispose() {
    _ticker.cancel();
    _businessSettingsRepository.removeListener(notifyListeners);
    if (_ownsBusinessSettingsRepository) _businessSettingsRepository.dispose();
    _toyRepository.removeListener(notifyListeners);
    if (_ownsToyRepository) _toyRepository.dispose();
    _rentalRepository.removeListener(notifyListeners);
    if (_ownsRentalRepository) _rentalRepository.dispose();
    super.dispose();
  }

  // ------------------------------ helpers ------------------------------

  Toy toyById(String id) => toys.firstWhere((t) => t.id == id, orElse: () => toys.first);

  String fmtMoney(double v) => formatMoney(v);


  String whenLabel(DateTime ts) => formatRelativeTime(ts);

  int toyAvailable(Toy t) {
    final rented = rentals.where((r) => r.status == RentalStatus.active && r.toyId == t.id).length;
    return t.qty - rented;
  }

  // ------------------------------ actions ------------------------------

  void setTab(AppTab t) {
    tab = t;
    notifyListeners();
  }

  void openNew() {
    final t = toys.firstWhere((t) => toyAvailable(t) > 0, orElse: () => toys.first);
    draft = RentalDraft(toyId: t.id, durationMin: t.blockMin, price: t.price);
    showNew = true;
    notifyListeners();
  }

  void closeNew() {
    showNew = false;
    notifyListeners();
  }

  void setDraftToy(String toyId) {
    final t = toyById(toyId);
    draft.toyId = toyId;
    draft.durationMin = t.blockMin;
    draft.price = t.price;
    draft.customRatePerMinute = null; // a rate typed for the old toy doesn't carry over
    notifyListeners();
  }

  void setDraftChild(String v) {
    draft.childName = v;
    notifyListeners();
  }

  void setDraftGuardian(String v) {
    draft.guardianName = v;
    notifyListeners();
  }

  void setDraftPhone(String v) {
    draft.guardianPhone = v;
    notifyListeners();
  }

  void applyDuration(int min) {
    final t = toyById(draft.toyId);
    // Matches the original's Math.round(price * (min / blockMin)).
    draft.durationMin = min;
    draft.price = (t.price * (min / t.blockMin)).round().toDouble();
    notifyListeners();
  }

  void setDraftPrice(double v) {
    draft.price = v;
    notifyListeners();
  }

  void setDraftOpenEnded(bool v) {
    draft.openEnded = v;
    notifyListeners();
  }

  void setDraftCustomRate(double? v) {
    draft.customRatePerMinute = v;
    notifyListeners();
  }

  /// Price per minute a toy earns, derived from its own block — the
  /// *suggested* rate a tempo-corrido rental pre-fills with. The operator
  /// can override it per rental (`RentalDraft.customRatePerMinute`); once
  /// the rental is created, [Rental.ratePerMinute] is what actually gets
  /// charged (see [computeFinalPrice]), not this.
  double ratePerMinute(Toy t) => t.price / t.blockMin;

  /// The price a rental should charge right now: the fixed [Rental.price]
  /// for a normal rental, or the live/final tempo-corrido estimate
  /// (elapsed minutes × the rate captured on the rental itself, rounded
  /// to the cent) for an open-ended one. Falls back to the toy's derived
  /// rate only if the rental predates `Rental.ratePerMinute` existing
  /// (older data/tests) — a rental created today always has one set.
  /// Used both by the active-rental card (live estimate) and by
  /// [confirmEnd] (the actual amount charged) so the two can never
  /// diverge — same formula, same call.
  double computeFinalPrice(Rental r) {
    if (!r.isOpenEnded) return r.price;
    final rate = r.ratePerMinute ?? ratePerMinute(toyById(r.toyId));
    final elapsedMin = DateTime.now().difference(r.startedAt).inMilliseconds / 60000;
    final raw = rate * elapsedMin;
    return (raw * 100).round() / 100;
  }

  void submitNew() {
    final d = draft;
    if (d.childName.trim().isEmpty) return;
    // RentalRepository.addNew builds the Rental (id, startedAt, status) —
    // spec 017-migracao-nova-locacao extracted that so NewRentalCubit
    // doesn't duplicate it. Same fields, same id scheme as before.
    final rental = _rentalRepository.addNew(
      toyId: d.toyId,
      childName: d.childName.trim(),
      guardianName: d.guardianName.trim().isEmpty ? '—' : d.guardianName.trim(),
      guardianPhone: d.guardianPhone.trim(),
      durationMin: d.openEnded ? null : d.durationMin,
      price: d.openEnded ? 0 : d.price,
      // Captured once, here — never re-derived from the toy later (see
      // the field's doc on `Rental`).
      ratePerMinute: d.openEnded ? (d.customRatePerMinute ?? ratePerMinute(toyById(d.toyId))) : null,
    );
    _scheduleEndNotification(rental);
    showNew = false;
    notifyListeners();
  }

  /// Tempo corrido (spec 006) has no target end time to notify about —
  /// only a fixed-duration rental gets the two notifications below (spec
  /// 005 + spec 009): the "time's up" one, and a "5 minutes left"
  /// heads-up before it. Delegates to [ScheduleRentalEndNotifications]
  /// (spec 017-migracao-nova-locacao) so `NewRentalCubit` doesn't
  /// duplicate this — same behavior as before, just extracted.
  static const _scheduleRentalEndNotifications = ScheduleRentalEndNotifications();

  void _scheduleEndNotification(Rental rental) {
    _scheduleRentalEndNotifications(rental, toyById(rental.toyId), notifications);
  }

  /// Adds `addMinutes` to an active fixed-duration rental (spec 008): its
  /// `durationMin` and `price` both grow (price proportionally, at the
  /// toy's rate/min — same formula as `ratePerMinute`), and both
  /// notifications (spec 005 "time's up" + spec 009 "5 minutes left") are
  /// cancelled and rescheduled for the new, later end time. No-op for
  /// `isOpenEnded` — "tempo corrido" has no fixed duration to extend.
  void extendActive(String rentalId, int addMinutes) {
    final r = rentals.firstWhere((r) => r.id == rentalId, orElse: () => rentals.first);
    if (r.isOpenEnded) return;
    final rate = r.ratePerMinute ?? ratePerMinute(toyById(r.toyId));
    final newDuration = r.durationMin! + addMinutes;
    final newPrice = ((r.price + rate * addMinutes) * 100).round() / 100;
    // RentalRepository.extend mutates + notifies (spec
    // 018-migracao-locacao-ativa-encerrar) — before this, mutating `r`
    // directly here never told RentalRepository's other listeners
    // (ReportCubit/ToyCatalogCubit) that anything changed.
    _rentalRepository.extend(rentalId, durationMin: newDuration, price: newPrice);
    notifications.cancelRentalEnd(r.id);
    notifications.cancelRentalEndingSoon(r.id);
    _scheduleEndNotification(r);
  }

  void cancelActive(String id) {
    notifications.cancelRentalEnd(id);
    notifications.cancelRentalEndingSoon(id);
    _rentalRepository.removeById(id);
  }

  void openEnd(String id) {
    endingId = id;
    endPayment = null;
    endShowPixQr = false;
    endFrozenPrice = null;
    notifyListeners();
  }

  void closeEnd() {
    endingId = null;
    endPayment = null;
    endShowPixQr = false;
    endFrozenPrice = null;
    notifyListeners();
  }

  void selectPayment(PaymentMethod m) {
    endPayment = m;
    notifyListeners();
  }

  /// Switches the still-open "Finalizar locação" dialog to the Pix QR
  /// step. Doesn't touch [endingId]/[endPayment] — [confirmEnd] still
  /// needs them when the operator finishes that step. Freezes
  /// [endFrozenPrice] right now, at the same value the QR is about to be
  /// generated from — see the field's doc for why that freeze matters.
  void showPixQrStep() {
    final r = rentals.firstWhere((r) => r.id == endingId);
    endFrozenPrice = computeFinalPrice(r);
    endShowPixQr = true;
    notifyListeners();
  }

  /// "Trocar forma" on the Pix QR step (spec 007-revisao-design-v3):
  /// backs out to payment-method selection without closing the "Finalizar
  /// locação" dialog — [endingId]/[endPayment] stay put, only the QR step
  /// and its frozen price reset (re-entering Pix re-freezes at whatever
  /// the price is by then).
  void hidePixQrStep() {
    endShowPixQr = false;
    endFrozenPrice = null;
    notifyListeners();
  }

  void confirmEnd() {
    if (endPayment == null || endingId == null) return;
    final r = rentals.firstWhere((r) => r.id == endingId);
    notifications.cancelRentalEnd(r.id);
    notifications.cancelRentalEndingSoon(r.id);
    // Reuse the price frozen when the Pix QR was generated, if there was
    // one — never recompute a tempo-corrido price after the QR was
    // already shown, or the amount charged could exceed what the
    // customer's bank app actually scanned.
    // RentalRepository.finish mutates + notifies (spec
    // 018-migracao-locacao-ativa-encerrar — same fix as extendActive).
    _rentalRepository.finish(
      r.id,
      endPayment!,
      finalPrice: r.isOpenEnded ? (endFrozenPrice ?? computeFinalPrice(r)) : null,
    );
    endingId = null;
    endPayment = null;
    endFrozenPrice = null;
    notifyListeners();
  }

  void updateToyPrice(String id, double v) => _toyRepository.updatePrice(id, v);

  void updateToyBlock(String id, int v) => _toyRepository.updateBlockMinutes(id, v);

  void addToy({
    required String name,
    required double price,
    required int blockMin,
    required ToyInk ink,
    required String imageKey,
    required ToyCategory category,
    int qty = 1,
  }) {
    _toyRepository.addNew(
      name: name,
      price: price,
      blockMin: blockMin,
      ink: ink,
      imageKey: imageKey,
      category: category,
      qty: qty,
    );
  }

  bool toyHasRentals(String id) => rentals.any((r) => r.toyId == id);

  /// Removes a toy from the catalog. Refuses (returns false) if any
  /// rental — active or in history — still references it, since
  /// [toyById]'s fallback would otherwise silently mislabel that entry.
  /// The guard stays here (not in `ToyRepository`) because it needs
  /// [rentals], a different domain that repository doesn't know about.
  bool removeToy(String id) {
    if (toyHasRentals(id)) return false;
    _toyRepository.remove(id);
    return true;
  }

  // ------------------------------ derived data ------------------------------

  List<Rental> get activeRentals => rentals.where((r) => r.status == RentalStatus.active).toList();

  String get kicker {
    final dt = DateTime.now();
    String pad2(int n) => n.toString().padLeft(2, '0');
    return 'PRAÇA DO PLANALTO · ${pad2(dt.day)}/${pad2(dt.month)}';
  }

  String get screenTitle => switch (tab) {
        AppTab.home => 'Painel do dia',
        AppTab.active => 'Em andamento',
        AppTab.catalog => 'Brinquedos',
        AppTab.report => 'Faturamento',
      };
}
