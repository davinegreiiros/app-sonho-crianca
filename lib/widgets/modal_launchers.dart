import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../ui/features/business_settings/views/business_settings_view.dart';
import '../ui/features/catalog/views/add_toy_sheet_view.dart';
import '../ui/features/rental/view_models/new_rental_cubit.dart';
import '../ui/features/rental/views/new_rental_sheet_view.dart';
import 'end_rental_dialog.dart';

/// Opens the "Nova locação" form as a real modal bottom sheet — slides up
/// from the bottom with the framework's own transition, dims the
/// backdrop. [NewRentalCubit.open] resets the form's own draft (spec
/// 017-migracao-nova-locacao — independent from `AppState.draft`, see
/// `NewRentalState`'s doc for why).
Future<void> showNewRentalSheet(BuildContext context) async {
  context.read<NewRentalCubit>().open();
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
  final state = context.read<AppState>();
  state.openEnd(rentalId);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: AppColors.overlayScrim.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const EndRentalDialog(),
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
  state.closeEnd();
}

/// Opens the "Adicionar brinquedo" form as a modal bottom sheet.
Future<void> showAddToySheet(BuildContext context) {
  return showModalBottomSheet<void>(
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
Future<void> openBusinessSettingsScreen(BuildContext context, {String? hint}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (context) => BusinessSettingsView(hint: hint)),
  );
}
