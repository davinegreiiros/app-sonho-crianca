import 'package:equatable/equatable.dart';

import '../../../../domain/models/rental.dart';
import '../../../../domain/models/toy.dart';
import '../../../../domain/models/turno.dart';

/// Who's using the app right now (spec 023-posto-monitor-painel):
/// `none` = just launched, choosing a posto (3a); `monitor` = inside a
/// single toy's posto (3b/3c); `admin` = "Entrar como administrador",
/// the app exactly as it was before this spec (`HomeShell`).
enum PostoMode { none, monitor, admin }

/// One row of the posto list in [PostoMode.none] (3a) — a toy plus its
/// currently open `Turno`, if any (`null` = livre).
typedef PostoSummary = ({Toy toy, Turno? openTurno});

/// State emitted by `PostoSessionCubit` — the current posto session plus
/// everything [OpenPostoView]/[CloseShiftView] need to render (spec
/// 023-posto-monitor-painel).
class PostoSessionState extends Equatable {
  const PostoSessionState({
    required this.mode,
    required this.toyId,
    required this.monitorName,
    required this.turnoId,
    required this.turnoOpenedAt,
    required this.postos,
    required this.closingExpectedByMethod,
    required this.closingCountedCashInput,
    required this.closingLocCount,
  });

  const PostoSessionState.initial()
      : mode = PostoMode.none,
        toyId = null,
        monitorName = null,
        turnoId = null,
        turnoOpenedAt = null,
        postos = const [],
        closingExpectedByMethod = const {},
        closingCountedCashInput = '',
        closingLocCount = 0;

  final PostoMode mode;
  final String? toyId;
  final String? monitorName;
  final String? turnoId;
  final DateTime? turnoOpenedAt;

  /// Only populated/relevant in [PostoMode.none] — the list 3a renders.
  final List<PostoSummary> postos;

  /// Esperado por forma de pagamento do turno atual — só populado
  /// enquanto [CloseShiftView] (3c) está aberta, via
  /// `PostoSessionCubit.beginClosing`.
  final Map<PaymentMethod, double> closingExpectedByMethod;

  /// Quantas locações entraram no cálculo de [closingExpectedByMethod] —
  /// só populado junto com ele, via `PostoSessionCubit.beginClosing`.
  final int closingLocCount;

  /// Draft do campo "quanto tem em dinheiro" de 3c (texto bruto, igual
  /// ao padrão de outros drafts de formulário no app — `NewRentalState`
  /// guarda `price` já convertido, mas aqui o texto pode estar
  /// incompleto/inválido enquanto o operador digita).
  final String closingCountedCashInput;

  double get closingExpectedCash => closingExpectedByMethod[PaymentMethod.dinheiro] ?? 0;

  double? get closingCountedCash => double.tryParse(closingCountedCashInput.replaceAll(',', '.'));

  /// `null` enquanto o campo está vazio/inválido — [CloseShiftView] trata
  /// isso como "ainda não confere", não como diferença zero.
  double? get closingDiff {
    final counted = closingCountedCash;
    if (counted == null) return null;
    return counted - closingExpectedCash;
  }

  PostoSessionState copyWith({
    PostoMode? mode,
    Object? toyId = _unset,
    Object? monitorName = _unset,
    Object? turnoId = _unset,
    Object? turnoOpenedAt = _unset,
    List<PostoSummary>? postos,
    Map<PaymentMethod, double>? closingExpectedByMethod,
    String? closingCountedCashInput,
    int? closingLocCount,
  }) {
    return PostoSessionState(
      mode: mode ?? this.mode,
      toyId: identical(toyId, _unset) ? this.toyId : toyId as String?,
      monitorName: identical(monitorName, _unset) ? this.monitorName : monitorName as String?,
      turnoId: identical(turnoId, _unset) ? this.turnoId : turnoId as String?,
      turnoOpenedAt: identical(turnoOpenedAt, _unset) ? this.turnoOpenedAt : turnoOpenedAt as DateTime?,
      postos: postos ?? this.postos,
      closingExpectedByMethod: closingExpectedByMethod ?? this.closingExpectedByMethod,
      closingCountedCashInput: closingCountedCashInput ?? this.closingCountedCashInput,
      closingLocCount: closingLocCount ?? this.closingLocCount,
    );
  }

  static const _unset = Object();

  @override
  List<Object?> get props => [
        mode,
        toyId,
        monitorName,
        turnoId,
        turnoOpenedAt,
        postos,
        closingExpectedByMethod,
        closingCountedCashInput,
        closingLocCount,
      ];
}
