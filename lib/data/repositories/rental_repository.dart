import 'package:flutter/foundation.dart';

import '../../domain/models/rental.dart';
import '../services/api_exceptions.dart';
import '../services/rental_remote_service.dart';
import 'auth_repository.dart';

/// Single source of truth for the toy-rental list (spec
/// 013-migracao-rental-repository-fundacao; sincronizado com o backend a
/// partir da 026-rental-via-backend) — one shared instance (wired in
/// `main.dart`).
///
/// Uma sessão só (spec 027-login-admin-sessao): leitura ([load]) e
/// mutações ([addNew]/[extend]/[cancel]/[finish]) usam
/// `AuthRepository.token`, a sessão do administrador salva no aparelho.
///
/// [rentals] continua a mesma lista mutável de sempre (não
/// `List.unmodifiable`) — vários Cubits e alguns testes (ex.
/// `posto_monitor_painel_test.dart`) dependem de poder inserir/ler nela
/// diretamente. Mutações desta classe nunca reatribuem [rentals] (é
/// `final`): usam `clear`/`addAll`/`add`/índice, preservando a mesma
/// instância pro ciclo de vida do Repository.
class RentalRepository extends ChangeNotifier {
  RentalRepository({required RentalRemoteService service, required AuthRepository authRepository})
      : _service = service,
        _authRepository = authRepository,
        rentals = [];

  /// Nasce com as 11 locações de demonstração (`a1`-`a3` ativas, `h1`-`h8`
  /// finalizadas) que `RentalRepository()` sempre semeou antes da spec
  /// 026 — vários testes dependem desses dados sem bater em backend
  /// nenhum. O app real nunca usa este construtor.
  @visibleForTesting
  RentalRepository.withDemoSeed({required RentalRemoteService service, required AuthRepository authRepository})
      : _service = service,
        _authRepository = authRepository,
        rentals = _seedInitial();

  /// Mesma lista de [withDemoSeed], exposta pra um teste poder semear o
  /// *backend fake* com os mesmos ids (`a1`-`a3`/`h1`-`h8`) — sem isso,
  /// `extend`/`cancel`/`finish` numa locação seedada bateria 404 contra
  /// um fake que nunca ouviu falar desses ids (o construtor só popula a
  /// lista local, não o "servidor").
  @visibleForTesting
  static List<Rental> demoSeedForTest() => _seedInitial();

  final RentalRemoteService _service;
  final AuthRepository _authRepository;
  final List<Rental> rentals;

  /// Set by [dispose] — mesmo motivo que os outros Repositories: um
  /// `await` em voo pode resolver depois deste já ter sido descartado.
  bool _disposed = false;

  static List<Rental> _seedInitial() {
    DateTime minAgo(num n) => DateTime.now().subtract(Duration(seconds: (n * 60).round()));
    DateTime dAgo(num n) => DateTime.now().subtract(Duration(seconds: (n * 86400).round()));
    DateTime todayAt(int h) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final at = start.add(Duration(hours: h));
      final cap = now.subtract(const Duration(minutes: 5));
      return at.isBefore(cap) ? at : cap;
    }

    return [
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
  }

  /// Busca o histórico no backend com a sessão do administrador (todas as
  /// páginas do cursor, ver `RentalRemoteService.loadAll`). Nunca propaga
  /// erro: sem sessão (não chama nada), sem rede ou 401 deixam [rentals]
  /// como estava (seed/último fetch bom) — mesma régua da 025 pro
  /// catálogo (cenário 5: fluxo principal do dia a dia não pode travar
  /// por conectividade). 401 ainda derruba a sessão (spec 027, cenário 8).
  Future<void> load() async {
    final token = _authRepository.token;
    if (token == null) return;
    try {
      final loaded = await _service.loadAll(token: token);
      if (_disposed) return;
      rentals
        ..clear()
        ..addAll(loaded);
      notifyListeners();
    } on ApiUnauthorizedException {
      if (!_disposed) await _authRepository.logout();
    } catch (e) {
      debugPrint('RentalRepository: falha ao carregar locações: ${e.runtimeType}');
    }
  }

  /// 401 numa escrita = token vencido/revogado no servidor: derruba a
  /// sessão local pra próxima ação pedir login (spec 027, cenário 8) em
  /// vez de repetir o mesmo token morto.
  Future<void> _dropSessionIfUnauthorized(Object error) async {
    if (error is ApiUnauthorizedException && !_disposed) await _authRepository.logout();
  }

  String _requireOperatorToken() {
    final token = _authRepository.token;
    if (token == null) throw const ApiUnauthorizedException('Sessão de operador necessária');
    return token;
  }

  /// Cria a locação no backend (sessão de operador real — já garantida ao
  /// abrir o posto, ou pela guarda de login em modo administrador). Sem
  /// sessão, lança antes de tocar em [rentals]. `createdByMonitorName` é
  /// preenchido aqui, localmente, com [createdByMonitorName] — nome
  /// digitado em "Quem é você hoje" (spec 023, `null` em modo
  /// administrador), **não** o nome de quem está logado: a sessão de
  /// operador real só serve pra autenticar a escrita no backend (spec
  /// 026 — "login fica só com o administrador"), nunca representa quem
  /// de fato está operando o posto. O backend não devolve nome nenhum
  /// (só `createdByOperatorId`), então isso nunca viria de lá mesmo.
  Future<Rental> addNew({
    required String toyId,
    required String childName,
    required String guardianName,
    required String guardianPhone,
    required int? durationMin,
    required double price,
    required double? ratePerMinute,
    String? createdByMonitorName,
  }) async {
    final token = _requireOperatorToken();
    final Rental rental;
    try {
      rental = await _service.create(
        toyId: toyId,
        childName: childName,
        guardianName: guardianName,
        guardianPhone: guardianPhone,
        startedAt: DateTime.now(),
        durationMin: durationMin,
        ratePerMinute: ratePerMinute,
        price: price,
        token: token,
      );
    } catch (e) {
      await _dropSessionIfUnauthorized(e);
      rethrow;
    }
    rental.createdByMonitorName = createdByMonitorName;
    if (!_disposed) {
      rentals.add(rental);
      notifyListeners();
    }
    return rental;
  }

  /// `durationMin` é o novo total absoluto (mesmo contrato que
  /// `ActiveRentalsCubit.extendActive` já usa) — a rota do backend espera
  /// o **incremento**, não o total, então o delta é calculado aqui antes
  /// de chamar o service (ver `plan.md`).
  Future<void> extend(String rentalId, {required int durationMin, required double price}) async {
    final token = _requireOperatorToken();
    final index = rentals.indexWhere((r) => r.id == rentalId);
    if (index == -1) return;
    final r = rentals[index];
    final previousDuration = r.durationMin;
    final previousPrice = r.price;
    final addMinutes = durationMin - (previousDuration ?? 0);
    r.durationMin = durationMin;
    r.price = price;
    notifyListeners();
    try {
      await _service.extend(rentalId, addMinutes, token: token);
    } catch (e) {
      if (!_disposed) {
        r.durationMin = previousDuration;
        r.price = previousPrice;
        notifyListeners();
      }
      await _dropSessionIfUnauthorized(e);
      rethrow;
    }
  }

  /// Cancela uma locação ativa (sem pagamento) — o backend marca `done`
  /// com `paymentMethod: null`, não deleta (ver `spec.md`, "Achado
  /// durante o planejamento"); [rentals] reflete esse mesmo estado em vez
  /// de remover o item (comportamento local anterior, pré-026).
  Future<void> cancel(String rentalId) async {
    final token = _requireOperatorToken();
    final index = rentals.indexWhere((r) => r.id == rentalId);
    if (index == -1) return;
    final r = rentals[index];
    final previousStatus = r.status;
    final previousEndedAt = r.endedAt;
    r.status = RentalStatus.done;
    r.endedAt = DateTime.now();
    notifyListeners();
    try {
      await _service.cancel(rentalId, token: token);
    } catch (e) {
      if (!_disposed) {
        r.status = previousStatus;
        r.endedAt = previousEndedAt;
        notifyListeners();
      }
      await _dropSessionIfUnauthorized(e);
      rethrow;
    }
  }

  /// Marca a locação finalizada (paga) — [finalPrice] só pra uma locação
  /// de tempo corrido (preço fixo nunca muda ao finalizar, mesmo contrato
  /// de sempre). [finishedByMonitorName]: mesmo rótulo local de
  /// [addNew], não quem está logado (ver doc ali).
  Future<void> finish(String rentalId, PaymentMethod method, {double? finalPrice, String? finishedByMonitorName}) async {
    final token = _requireOperatorToken();
    final index = rentals.indexWhere((r) => r.id == rentalId);
    if (index == -1) return;
    final r = rentals[index];
    final previousStatus = r.status;
    final previousEndedAt = r.endedAt;
    final previousPaymentMethod = r.paymentMethod;
    final previousPrice = r.price;
    final previousFinishedBy = r.finishedByMonitorName;
    if (finalPrice != null) r.price = finalPrice;
    r.finish(method, finishedByMonitorName: finishedByMonitorName);
    notifyListeners();
    try {
      await _service.finish(rentalId, method, finalPrice: finalPrice, token: token);
    } catch (e) {
      if (!_disposed) {
        r.status = previousStatus;
        r.endedAt = previousEndedAt;
        r.paymentMethod = previousPaymentMethod;
        r.price = previousPrice;
        r.finishedByMonitorName = previousFinishedBy;
        notifyListeners();
      }
      await _dropSessionIfUnauthorized(e);
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
