import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'add_toy_sheet.dart';
import 'business_settings_sheet.dart';
import 'end_rental_dialog.dart';
import 'new_rental_sheet.dart';

/// Opens the "Nova locação" form as a real modal bottom sheet — slides up
/// from the bottom with the framework's own transition, dims the
/// backdrop. [AppState.showNew] stays as the source of truth for the
/// form fields, but the sheet's presence is now an actual [ModalRoute]
/// instead of a hand-rolled overlay.
Future<void> showNewRentalSheet(BuildContext context) async {
  final state = context.read<AppState>();
  state.openNew();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.text.withValues(alpha: 0.5),
    builder: (context) => const NewRentalSheet(),
  );
  state.closeNew();
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
    builder: (context) => const AddToySheet(),
  );
}

/// Opens "Configurações do negócio" (name/city/Pix key — spec
/// 004-pix-qrcode) as a modal bottom sheet. [hint] is shown when this was
/// triggered by picking "Pix" before anything was configured yet.
Future<void> showBusinessSettingsSheet(BuildContext context, {String? hint}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.text.withValues(alpha: 0.5),
    builder: (context) => BusinessSettingsSheet(hint: hint),
  );
}
