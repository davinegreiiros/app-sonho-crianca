import 'package:flutter/foundation.dart';

import '../../domain/models/toy.dart';
import '../../theme/app_colors.dart' show ToyInk;
import '../services/api_exceptions.dart';
import '../services/toy_remote_service.dart';
import 'auth_repository.dart';

/// Single source of truth for the toy catalog (spec
/// 012-migracao-catalogo-criacao; sincronizado com o backend a partir da
/// 025-catalogo-sessao-dispositivo) — one shared instance (wired in
/// `main.dart`) consumed both by `ToyCatalogCubit` (new world,
/// `lib/ui/features/catalog/`) and by outros Cubits que só leem `toys`
/// (home, report, posto, admin panel).
///
/// Uma sessão só (spec 027-login-admin-sessao, revisando a "sessão de
/// dispositivo" da 025): leitura e escrita usam `AuthRepository.token`, a
/// sessão do administrador — salva no aparelho, então o posto sem conta
/// continua lendo o catálogo depois que o administrador volta pros postos.
class ToyRepository extends ChangeNotifier {
  ToyRepository({required ToyRemoteService service, required AuthRepository authRepository})
      : _service = service,
        _authRepository = authRepository,
        _toys = List.of(kInitialToys);

  final ToyRemoteService _service;
  final AuthRepository _authRepository;

  List<Toy> _toys;
  List<Toy> get toys => List.unmodifiable(_toys);

  /// Set by [dispose] — mesmo motivo que os outros Repositories: um
  /// `await` em voo pode resolver depois deste já ter sido descartado.
  bool _disposed = false;

  /// Busca o catálogo no backend com a sessão do administrador. Nunca
  /// propaga erro: sem sessão (não chama nada), sem rede ou 401 deixam o
  /// catálogo como estava (seed inicial ou último fetch bom); 401 ainda
  /// derruba a sessão (token vencido/revogado — spec 027, cenário 8).
  /// Catálogo é o fluxo principal do posto (spec 023) — não pode travar
  /// nem ficar em branco por causa de conectividade (spec 025, cenário 4).
  Future<void> load() async {
    final token = _authRepository.token;
    if (token == null) return;
    try {
      final loaded = await _service.loadAll(token: token);
      if (_disposed) return;
      _toys = loaded;
      notifyListeners();
    } on ApiUnauthorizedException {
      if (!_disposed) await _authRepository.logout();
    } catch (_) {
      // Sem rede, backend fora — mantém o catálogo que já tinha, silencioso.
    }
  }

  /// Cria o brinquedo no backend (sessão de operador real) — sem valor
  /// otimista: a tela (`AddToySheetView`) só fecha em sucesso confirmado,
  /// mesmo padrão de `BusinessSettingsView._save`. Deixa
  /// `ApiUnauthorizedException`/`ApiNetworkException`/`ApiException` subir.
  Future<Toy> addNew({
    required String name,
    required double price,
    required int blockMin,
    required ToyInk ink,
    required String imageKey,
    required ToyCategory category,
    int qty = 1,
  }) async {
    final Toy toy;
    try {
      toy = await _service.create(
        name: name,
        qty: qty,
        blockMin: blockMin,
        price: price,
        ink: ink,
        imageKey: imageKey,
        category: category,
        token: _authRepository.token,
      );
    } catch (e) {
      await _dropSessionIfUnauthorized(e);
      rethrow;
    }
    if (!_disposed) {
      _toys = [..._toys, toy];
      notifyListeners();
    }
    return toy;
  }

  /// Otimista (atualiza na hora, pro grid responder imediato), mas com
  /// reversão: falha desfaz a mudança local antes de relançar, pro
  /// catálogo nunca divergir silenciosamente do backend (ao contrário do
  /// SQLite local de antes, uma chamada HTTP falha de verdade — sem rede,
  /// sessão expirada).
  Future<void> updatePrice(String id, double price) {
    return _writeField(
      id: id,
      applyLocally: (t) => t.copyWith(price: price),
      callRemote: () => _service.updatePrice(id, price, token: _authRepository.token),
    );
  }

  Future<void> updateBlockMinutes(String id, int blockMin) {
    return _writeField(
      id: id,
      applyLocally: (t) => t.copyWith(blockMin: blockMin),
      callRemote: () => _service.updateBlockMin(id, blockMin, token: _authRepository.token),
    );
  }

  Future<void> _writeField({
    required String id,
    required Toy Function(Toy) applyLocally,
    required Future<Toy> Function() callRemote,
  }) async {
    final previous = _toys;
    _toys = previous.map((t) => t.id == id ? applyLocally(t) : t).toList();
    notifyListeners();
    try {
      final confirmed = await callRemote();
      if (_disposed) return;
      _toys = _toys.map((t) => t.id == id ? confirmed : t).toList();
      notifyListeners();
    } catch (e) {
      if (!_disposed) {
        _toys = previous;
        notifyListeners();
      }
      await _dropSessionIfUnauthorized(e);
      rethrow;
    }
  }

  /// Remoção otimista com reversão — backend recusa (409, `ApiException`)
  /// se houver `Rental` vinculado (spec 001, cenário 6); a View mostra a
  /// mensagem que o próprio backend devolveu.
  Future<void> remove(String id) async {
    final previous = _toys;
    _toys = previous.where((t) => t.id != id).toList();
    notifyListeners();
    try {
      await _service.remove(id, token: _authRepository.token);
    } catch (e) {
      if (!_disposed) {
        _toys = previous;
        notifyListeners();
      }
      await _dropSessionIfUnauthorized(e);
      rethrow;
    }
  }

  /// 401 numa escrita = token vencido/revogado no servidor: derruba a
  /// sessão local pra próxima ação pedir login (spec 027, cenário 8).
  Future<void> _dropSessionIfUnauthorized(Object error) async {
    if (error is ApiUnauthorizedException && !_disposed) await _authRepository.logout();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
