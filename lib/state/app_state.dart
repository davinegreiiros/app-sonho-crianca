import 'dart:async';
import 'package:flutter/material.dart';

import '../models/rental.dart';
import '../models/toy.dart';
import '../theme/app_colors.dart';

enum AppTab { home, active, catalog, report }

enum ReportPeriod { today, week, all }

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
}

/// Central app state, ported from the original `.dc.html` Component logic:
/// toy catalog, rentals (active + history), the "nova locação" draft, the
/// end-rental flow, and the report period filter. A 1s ticker keeps active
/// rental countdowns live.
class AppState extends ChangeNotifier {
  AppState() {
    _seed();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
  }

  // ---- config (design-time props in the original, fixed defaults here) ----
  static const Color _alertColor = AppColors.statusUrgent;
  static const bool _pulseOnOvertime = true;
  static const int _reportWindowDays = 14;

  late final Timer _ticker;

  AppTab tab = AppTab.home;
  List<Toy> toys = [];
  List<Rental> rentals = [];

  bool showNew = false;
  late RentalDraft draft;

  String? endingId;
  PaymentMethod? endPayment;

  ReportPeriod reportPeriod = ReportPeriod.today;

  void _seed() {
    toys = kInitialToys.map((t) => t).toList();

    DateTime minAgo(num n) => DateTime.now().subtract(Duration(seconds: (n * 60).round()));
    DateTime dAgo(num n) => DateTime.now().subtract(Duration(seconds: (n * 86400).round()));
    DateTime todayAt(int h) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final at = start.add(Duration(hours: h));
      final cap = now.subtract(const Duration(minutes: 5));
      return at.isBefore(cap) ? at : cap;
    }

    rentals = [
      Rental(id: 'a1', toyId: 'carrinho', childName: 'Sofia', guardianName: 'Camila Ramos', guardianPhone: '(85) 98888-1010', startedAt: minAgo(9), durationMin: 15, price: 10, status: RentalStatus.active),
      Rental(id: 'a2', toyId: 'pula', childName: 'Enzo', guardianName: 'Marcos Lima', guardianPhone: '(85) 99999-2020', startedAt: minAgo(32), durationMin: 30, price: 12, status: RentalStatus.active),
      Rental(id: 'a3', toyId: 'patinete', childName: 'Lívia', guardianName: 'Ana Souza', guardianPhone: '(85) 98777-3030', startedAt: minAgo(3), durationMin: 15, price: 12, status: RentalStatus.active),
      Rental(id: 'h1', toyId: 'carrinho', childName: 'Davi', guardianName: 'Renata Alves', startedAt: todayAt(9).subtract(const Duration(minutes: 15)), durationMin: 15, price: 10, status: RentalStatus.done, endedAt: todayAt(9), paymentMethod: PaymentMethod.pix),
      Rental(id: 'h2', toyId: 'cama', childName: 'Manuela', guardianName: 'Bruno Costa', startedAt: todayAt(10).subtract(const Duration(minutes: 30)), durationMin: 30, price: 15, status: RentalStatus.done, endedAt: todayAt(10), paymentMethod: PaymentMethod.dinheiro),
      Rental(id: 'h3', toyId: 'piscina', childName: 'Théo', guardianName: 'Juliana Dias', startedAt: todayAt(11).subtract(const Duration(minutes: 20)), durationMin: 20, price: 10, status: RentalStatus.done, endedAt: todayAt(11), paymentMethod: PaymentMethod.cartao),
      Rental(id: 'h4', toyId: 'pula', childName: 'Alice', guardianName: 'Paulo Nunes', startedAt: dAgo(1), durationMin: 30, price: 24, status: RentalStatus.done, endedAt: dAgo(1).add(const Duration(minutes: 30)), paymentMethod: PaymentMethod.pix),
      Rental(id: 'h5', toyId: 'patinete', childName: 'Gabriel', guardianName: 'Carla Mota', startedAt: dAgo(1.2), durationMin: 15, price: 12, status: RentalStatus.done, endedAt: dAgo(1.2).add(const Duration(minutes: 15)), paymentMethod: PaymentMethod.dinheiro),
      Rental(id: 'h6', toyId: 'carrinho', childName: 'Isabela', guardianName: 'Fábio Reis', startedAt: dAgo(2), durationMin: 15, price: 10, status: RentalStatus.done, endedAt: dAgo(2).add(const Duration(minutes: 15)), paymentMethod: PaymentMethod.cartao),
      Rental(id: 'h7', toyId: 'cama', childName: 'Miguel', guardianName: 'Larissa Pinto', startedAt: dAgo(3.4), durationMin: 30, price: 15, status: RentalStatus.done, endedAt: dAgo(3.4).add(const Duration(minutes: 30)), paymentMethod: PaymentMethod.pix),
      Rental(id: 'h8', toyId: 'piscina', childName: 'Helena', guardianName: 'Diego Farias', startedAt: dAgo(5.5), durationMin: 20, price: 10, status: RentalStatus.done, endedAt: dAgo(5.5).add(const Duration(minutes: 20)), paymentMethod: PaymentMethod.pix),
    ];

    final first = toys.firstWhere((t) => toyAvailable(t) > 0, orElse: () => toys.first);
    draft = RentalDraft(toyId: first.id, durationMin: first.blockMin, price: first.price);
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  // ------------------------------ helpers ------------------------------

  Toy toyById(String id) => toys.firstWhere((t) => t.id == id, orElse: () => toys.first);

  String fmtMoney(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  Color statusColor(double ratio, bool overtime) {
    if (overtime || ratio <= 0.2) return _alertColor;
    if (ratio <= 0.5) return AppColors.statusWarn;
    return AppColors.statusOk;
  }

  String fmtClock(double remainMin) {
    final overtime = remainMin < 0;
    final abs = remainMin.abs();
    final mm = abs.floor();
    final ss = ((abs - mm) * 60).round();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${overtime ? '+' : ''}${pad(mm)}:${pad(ss)}';
  }

  String whenLabel(DateTime ts) {
    final min = DateTime.now().difference(ts).inSeconds / 60;
    if (min < 60) return 'há ${(min < 1 ? 1 : min.round())} min';
    final h = min / 60;
    if (h < 24) return 'há ${h.round()}h';
    return 'há ${(h / 24).round()}d';
  }

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

  void submitNew() {
    final d = draft;
    if (d.childName.trim().isEmpty) return;
    rentals.add(Rental(
      id: 'r${DateTime.now().microsecondsSinceEpoch}',
      toyId: d.toyId,
      childName: d.childName.trim(),
      guardianName: d.guardianName.trim().isEmpty ? '—' : d.guardianName.trim(),
      guardianPhone: d.guardianPhone.trim(),
      startedAt: DateTime.now(),
      durationMin: d.durationMin,
      price: d.price,
      status: RentalStatus.active,
    ));
    showNew = false;
    notifyListeners();
  }

  void cancelActive(String id) {
    rentals.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void openEnd(String id) {
    endingId = id;
    endPayment = null;
    notifyListeners();
  }

  void closeEnd() {
    endingId = null;
    endPayment = null;
    notifyListeners();
  }

  void selectPayment(PaymentMethod m) {
    endPayment = m;
    notifyListeners();
  }

  void confirmEnd() {
    if (endPayment == null || endingId == null) return;
    final r = rentals.firstWhere((r) => r.id == endingId);
    r.finish(endPayment!);
    endingId = null;
    endPayment = null;
    notifyListeners();
  }

  void setReportPeriod(ReportPeriod p) {
    reportPeriod = p;
    notifyListeners();
  }

  void updateToyPrice(String id, double v) {
    toys = toys.map((t) => t.id == id ? t.copyWith(price: v) : t).toList();
    notifyListeners();
  }

  void updateToyBlock(String id, int v) {
    toys = toys.map((t) => t.id == id ? t.copyWith(blockMin: v) : t).toList();
    notifyListeners();
  }

  void addToy({
    required String name,
    required double price,
    required int blockMin,
    required ToyInk ink,
    required String imageKey,
    int qty = 1,
  }) {
    final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    toys = [...toys, Toy(id: id, name: name, qty: qty, blockMin: blockMin, price: price, ink: ink, imageKey: imageKey)];
    notifyListeners();
  }

  bool toyHasRentals(String id) => rentals.any((r) => r.toyId == id);

  /// Removes a toy from the catalog. Refuses (returns false) if any
  /// rental — active or in history — still references it, since
  /// [toyById]'s fallback would otherwise silently mislabel that entry.
  bool removeToy(String id) {
    if (toyHasRentals(id)) return false;
    toys = toys.where((t) => t.id != id).toList();
    notifyListeners();
    return true;
  }

  // ------------------------------ derived data ------------------------------

  List<Rental> get activeRentals => rentals.where((r) => r.status == RentalStatus.active).toList();

  DateTime get _startOfDay {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<Rental> get doneAll => rentals.where((r) => r.status == RentalStatus.done).toList();

  List<Rental> get doneToday => doneAll.where((r) => r.endedAt != null && !r.endedAt!.isBefore(_startOfDay)).toList();

  double get homeTotalToday => doneToday.fold(0.0, (a, r) => a + r.price);

  List<Rental> get recentActivity {
    final combined = [...activeRentals, ...doneToday];
    combined.sort((a, b) {
      final ta = a.status == RentalStatus.active ? a.startedAt : a.endedAt!;
      final tb = b.status == RentalStatus.active ? b.startedAt : b.endedAt!;
      return tb.compareTo(ta);
    });
    return combined.take(4).toList();
  }

  DateTime get _reportCutoff {
    switch (reportPeriod) {
      case ReportPeriod.today:
        return _startOfDay;
      case ReportPeriod.week:
        return DateTime.now().subtract(const Duration(days: _reportWindowDays));
      case ReportPeriod.all:
        return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  List<Rental> get reportFiltered =>
      doneAll.where((r) => r.endedAt != null && !r.endedAt!.isBefore(_reportCutoff)).toList();

  double get reportTotal => reportFiltered.fold(0.0, (a, r) => a + r.price);

  Map<PaymentMethod, double> get paymentBreakdown {
    final map = <PaymentMethod, double>{};
    for (final m in PaymentMethod.values) {
      map[m] = reportFiltered.where((r) => r.paymentMethod == m).fold(0.0, (a, r) => a + r.price);
    }
    return map;
  }

  List<MapEntry<Toy, ({int count, double total})>> get toyBreakdown {
    final totals = <String, ({int count, double total})>{};
    for (final r in reportFiltered) {
      final cur = totals[r.toyId] ?? (count: 0, total: 0.0);
      totals[r.toyId] = (count: cur.count + 1, total: cur.total + r.price);
    }
    final entries = totals.entries.map((e) => MapEntry(toyById(e.key), e.value)).toList();
    entries.sort((a, b) => b.value.total.compareTo(a.value.total));
    return entries;
  }

  List<Rental> get historyList {
    final list = [...reportFiltered];
    list.sort((a, b) => b.endedAt!.compareTo(a.endedAt!));
    return list;
  }

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

  bool get pulseOnOvertime => _pulseOnOvertime;
}
