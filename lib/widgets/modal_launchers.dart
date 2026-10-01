import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/toy_repository.dart';
import '../theme/app_colors.dart';
import '../ui/features/admin_panel/views/admin_panel_view.dart';
import '../ui/features/business_settings/views/business_settings_view.dart';
import '../ui/features/catalog/views/add_toy_sheet_view.dart';
import '../ui/features/posto/view_models/posto_session_cubit.dart';
import '../ui/features/posto/view_models/posto_session_state.dart';
import '../ui/features/rental/view_models/active_rentals_cubit.dart';
import '../ui/features/rental/view_models/new_rental_cubit.dart';
import '../ui/features/rental/views/end_rental_dialog_view.dart';
import '../ui/features/rental/views/new_rental_sheet_view.dart';
import 'auth_gate.dart';
import 'rental_action_error.dart';

/// Opens the "Nova locação" form as a real modal bottom sheet — slides up
/// from the bottom with the framework's own transition, dims the
/// backdrop. [NewRentalCubit.open] resets the form's own draft (spec
/// 017-migracao-nova-locacao — independent from `AppState.draft`, see
/// `NewRentalState`'s doc for why).
///
/// Guards on an empty catalog first: [NewRentalCubit.open] always picks
/// *some* toy for the draft (needs one to compute duration/price), which
/// has no sane answer with zero toys — bail out with a message instead of
/// letting that pick blow up.
///
/// [lockedToyId] (spec 023-posto-monitor-painel): quando vem de
/// [MonitorPostoView], trava o brinquedo antes de abrir — a sheet
/// (`NewRentalSheetView`) esconde o seletor sozinha, olhando pro modo da
/// sessão de posto, mas o draft precisa nascer com o `toyId` certo.
Future<void> showNewRentalSheet(BuildContext context, {String? lockedToyId}) async {
  if (context.read<ToyRepository>().toys.isEmpty) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Cadastre um brinquedo no catálogo antes de registrar uma locação.'),
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }
  final newRentalCubit = context.read<NewRentalCubit>();
  newRentalCubit.open();
  if (lockedToyId != null) newRentalCubit.setToy(lockedToyId);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.text.withValues(alpha: 0.5),
    builder: (context) => const NewRentalSheetView(),
  );
}

/// Opens the "Finalizar locação" confirmation as a dialog that pops in
/// with an elastic overshoot ([Curves.easeOutBack]) over a fading
/// backdrop.
Future<void> showEndRentalDialog(BuildContext context, String rentalId) async {
  final cubit = context.read<ActiveRentalsCubit>();
  cubit.openEnd(rentalId);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: AppColors.overlayScrim.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const EndRentalDialogView(),
    transitionBuilder: (context, animation, _, child) {
      final scale = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
  cubit.closeEnd();
}

/// Confirma o fim da locação (spec 026-rental-via-backend) — chamado por
/// `EndRentalDialogView` (pagamento não-Pix) e `PixQrSheetView` (depois
/// do QR). No fluxo do posto (`PostoMode.monitor`), a sessão real já
/// existe desde que o turno abriu — `ensureOperatorSession` só confirma;
/// em modo administrador pode ser a primeira ação sensível da sessão.
/// Falha mantém o diálogo aberto (não finge sucesso, não perde a forma de
/// pagamento já escolhida).
Future<void> confirmEndRental(BuildContext context, ActiveRentalsCubit cubit) async {
  final inPosto = context.read<PostoSessionCubit>().state.mode == PostoMode.monitor;
  if (!inPosto && !await ensureOperatorSession(context)) return;
  if (!context.mounted) return;
  try {
    await cubit.confirmEnd();
    if (context.mounted) Navigator.of(context).pop();
  } catch (e) {
    if (context.mounted) showRentalActionError(context, e);
  }
}

/// Opens the "Adicionar brinquedo" form as a modal bottom sheet.
///
/// Guarda de login (spec 025-catalogo-sessao-dispositivo): criar brinquedo
/// grava autoria de operador real (não a sessão de dispositivo, que só
/// lê) — mesma guarda de [openBusinessSettingsScreen], reaproveitada via
/// `ensureOperatorSession`.
Future<void> showAddToySheet(BuildContext context) async {
  if (!await ensureOperatorSession(context)) return;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.text.withValues(alpha: 0.5),
    builder: (context) => const AddToySheetView(),
  );
}

/// Opens "Configurações do negócio" (name/city/Pix key — spec
/// 004-pix-qrcode) as a full-page destination (spec 007-revisao-design-v3,
/// artboard 1d: it's navigation, not a flow form). [hint] is shown when
/// this was triggered by picking "Pix" before anything was configured yet.
///
/// Guarda de login (spec 024-sync-backend-fundacao, cenário 8) — único
/// ponto de entrada em [BusinessSettingsView], vale pro botão do painel
/// administrativo e pro atalho de Pix em `end_rental_dialog_view.dart`:
/// sem sessão, empurra [LoginView] primeiro; se o operador cancelar (volta
/// sem logar), nunca chega a abrir Configurações. Sessão expirar *durante*
/// o uso da tela (cenário 5) volta pra cá com um aviso.
Future<void> openBusinessSettingsScreen(BuildContext context, {String? hint}) async {
  if (!await ensureOperatorSession(context)) return;
  if (!context.mounted) return;

  final exitReason = await Navigator.of(context).push<BusinessSettingsExitReason>(
    MaterialPageRoute(builder: (context) => BusinessSettingsView(hint: hint)),
  );
  if (exitReason == BusinessSettingsExitReason.sessionExpired && context.mounted) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Sessão expirada — faça login novamente.'), duration: Duration(seconds: 3)),
    );
  }
}

/// Opens o painel administrativo (3d, spec 023-posto-monitor-painel) como
/// tela cheia — mesmo padrão de [openBusinessSettingsScreen]. Só chegável
/// em modo administrador (único jeito de estar no `HomeShell`).
Future<void> openAdminPanelScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (context) => const AdminPanelView()),
  );
}
