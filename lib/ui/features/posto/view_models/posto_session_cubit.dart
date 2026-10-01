import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/repositories/rental_repository.dart';
import '../../../../data/repositories/toy_repository.dart';
import '../../../../data/repositories/turno_repository.dart';
import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';
import '../../../../domain/models/turno.dart';
import 'posto_session_state.dart';

/// ViewModel for the posto session (spec 023-posto-monitor-painel) —
/// drives [OpenPostoView] (3a: list of postos + open/resume) and
/// [CloseShiftView] (3c: esperado por forma de pagamento + fechar).
/// [MonitorPostoView] (3b) reads this only for the header (toyId/monitor
/// name/turno) — the actual active-rental list stays on the shared
/// `ActiveRentalsCubit`, filtered by `toyId` in the View (see `plan.md`:
/// modo administrador continua precisando da lista global inalterada).
class PostoSessionCubit extends Cubit<PostoSessionState> {
  PostoSessionCubit(
    ToyRepository toyRepository,
    RentalRepository rentalRepository,
    TurnoRepository turnoRepository, {
    // Só pra teste: nasce direto em modo administrador (mesma tela de
    // hoje), sem passar pela seleção de posto — produção nunca passa
    // isto (ver `plan.md`, seção "Riscos").
    bool startInAdminMode = false,
  })  : _toyRepository = toyRepository,
        _rentalRepository = rentalRepository,
        _turnoRepository = turnoRepository,
        super(
          startInAdminMode
              ? const PostoSessionState.initial().copyWith(mode: PostoMode.admin)
              : PostoSessionState.initial().copyWith(postos: _computePostos(toyRepository.toys, turnoRepository.turnos)),
        ) {
    _toyRepository.addListener(_onCatalogOrTurnosChanged);
    _turnoRepository.addListener(_onCatalogOrTurnosChanged);
  }

  final ToyRepository _toyRepository;
  final RentalRepository _rentalRepository;
  final TurnoRepository _turnoRepository;

  static List<PostoSummary> _computePostos(List<Toy> toys, List<Turno> turnos) =>
      toys.map((t) => (toy: t, openTurno: _openTurnoFor(turnos, t.id))).toList();

  static Turno? _openTurnoFor(List<Turno> turnos, String toyId) {
    for (final t in turnos) {
      if (t.toyId == toyId && t.isOpen) return t;
    }
    return null;
  }

  void _onCatalogOrTurnosChanged() {
    if (state.mode != PostoMode.none) return;
    emit(state.copyWith(postos: _computePostos(_toyRepository.toys, _turnoRepository.turnos)));
  }

  /// Toca num posto em 3a: se já tem turno aberto pra esse `toyId`,
  /// retoma direto (cenário 2 do spec, nunca cria um segundo turno pro
  /// mesmo brinquedo); senão abre um novo com [monitorName] (obrigatório
  /// nesse caso).
  void openOrResume(String toyId, {String? monitorName}) {
    final existing = _turnoRepository.openTurnoFor(toyId);
    final turno = existing ?? _turnoRepository.open(toyId, (monitorName ?? '').trim());
    emit(state.copyWith(
      mode: PostoMode.monitor,
      toyId: toyId,
      monitorName: turno.monitorName,
      turnoId: turno.id,
      turnoOpenedAt: turno.openedAt,
    ));
  }

  void enterAdmin() => emit(state.copyWith(mode: PostoMode.admin));

  /// Volta pra 3a sem fechar o turno atual (se houver) — ele continua
  /// aberto no banco, retomável depois (decisão do spec: sessão não
  /// persiste entre reinícios, o `Turno` em si persiste).
  void exitToSelection() => emit(PostoSessionState.initial().copyWith(
        postos: _computePostos(_toyRepository.toys, _turnoRepository.turnos),
      ));

  /// Abre o passo de conferência de caixa (3c): calcula o esperado por
  /// forma de pagamento a partir das locações encerradas neste turno
  /// (mesmo `toyId`, `endedAt` dentro de `[turnoOpenedAt, agora]`, e
  /// encerradas pelo próprio monitor do turno — encerramento feito pelo
  /// administrador ou outra pessoa não entra no caixa dele).
  void beginClosing() {
    final toyId = state.toyId;
    final openedAt = state.turnoOpenedAt;
    final monitorName = state.monitorName;
    if (toyId == null || openedAt == null || monitorName == null) return;
    final finished = _rentalRepository.rentals.where(
      (r) =>
          r.toyId == toyId &&
          r.status == RentalStatus.done &&
          r.endedAt != null &&
          !r.endedAt!.isBefore(openedAt) &&
          r.finishedByMonitorName == monitorName,
    );
    final expected = <PaymentMethod, double>{
      for (final m in PaymentMethod.values) m: finished.where((r) => r.paymentMethod == m).fold(0.0, (a, r) => a + r.price),
    };
    emit(state.copyWith(closingExpectedByMethod: expected, closingCountedCashInput: '', closingLocCount: finished.length));
  }

  void setClosingCountedCash(String raw) => emit(state.copyWith(closingCountedCashInput: raw));

  /// Confirma o fechamento do turno atual e volta pra 3a (posto livre de
  /// novo). Não fecha com o campo de dinheiro vazio/inválido — gravaria
  /// uma falta inventada num turno que não pode mais ser corrigido; `0`
  /// digitado explicitamente vale.
  void confirmCloseTurno() {
    final turnoId = state.turnoId;
    final countedCash = state.closingCountedCash;
    if (turnoId == null || countedCash == null) return;
    _turnoRepository.close(turnoId, countedCash: countedCash);
    exitToSelection();
  }

  @override
  Future<void> close() {
    _toyRepository.removeListener(_onCatalogOrTurnosChanged);
    _turnoRepository.removeListener(_onCatalogOrTurnosChanged);
    return super.close();
  }
}
