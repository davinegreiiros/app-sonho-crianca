import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rental.dart';
import '../state/app_state.dart';
import '../test_keys.dart';
import '../theme/app_colors.dart';
import 'animations/pressable.dart';
import 'modal_launchers.dart';
import 'pix_qr_sheet.dart';

/// "Finalizar locação" confirmation card: picks a payment method, then
/// commits the rental as done. Layout ported 1:1 from the design source's
/// `showEnd` overlay (title/summary/payment-row/button-row, gap 14).
class EndRentalDialog extends StatelessWidget {
  const EndRentalDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // `endingId` can already be null here: `confirmEnd()`/`closeEnd()` fire
    // notifyListeners() (rebuilding this widget) before Navigator.pop()
    // finishes unmounting it. Render nothing rather than crash in that gap.
    Rental? rental;
    for (final r in state.rentals) {
      if (r.id == state.endingId) {
        rental = r;
        break;
      }
    }
    if (rental == null) return const SizedBox.shrink();
    if (state.endShowPixQr) return PixQrSheet(rentalId: rental.id);
    final toy = state.toyById(rental.toyId);
    final finalPrice = state.computeFinalPrice(rental);
    final summary =
        '${toy.name} · ${rental.childName} · ${state.fmtMoney(finalPrice)}';
    final canConfirm = state.endPayment != null;

    // `showGeneralDialog` (unlike `showModalBottomSheet`) doesn't wrap its
    // content in a `Material` ancestor — without one, plain `Text` here
    // falls back to the engine's unstyled default paint (shows up red and
    // underlined) instead of inheriting the app's theme. `Material` restores
    // that inherited `DefaultTextStyle`, matching every other sheet/dialog.
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: AppColors.overlayScrim.withValues(alpha: 0.22),
                  offset: const Offset(0, 12),
                  blurRadius: 32,
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Finalizar locação',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                Text(
                  summary,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.text.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Forma de pagamento',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.text.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final m in PaymentMethod.values) ...[
                      if (m != PaymentMethod.values.first)
                        const SizedBox(width: 8),
                      Expanded(
                        child: Pressable(
                          child: _PaymentOption(
                            key: TestKeys.paymentOption(m.name),
                            label: m.label,
                            selected: state.endPayment == m,
                            onTap: () => state.selectPayment(m),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Pressable(
                        child: OutlinedButton(
                          onPressed: () {
                            state.closeEnd();
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.text,
                            side: BorderSide(
                              color: AppColors.text.withValues(alpha: 0.16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Voltar'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Pressable(
                        child: Opacity(
                          // Design fades the whole button to 0.5 rather than
                          // recoloring it, so the accent stays true.
                          opacity: canConfirm ? 1 : 0.5,
                          child: ElevatedButton(
                            key: TestKeys.confirmEndButton,
                            onPressed: canConfirm
                                ? () {
                                    // Pix (spec 004): show the QR before actually
                                    // committing — same dialog route, so it never
                                    // races with `closeEnd()` resetting the ids
                                    // this needs once the QR step confirms.
                                    if (state.endPayment == PaymentMethod.pix) {
                                      if (!state.businessSettings.isConfigured) {
                                        state.closeEnd();
                                        Navigator.of(context).pop();
                                        showBusinessSettingsSheet(
                                          context,
                                          hint: 'Configure isso antes de cobrar por Pix.',
                                        );
                                        return;
                                      }
                                      state.showPixQrStep();
                                      return;
                                    }
                                    state.confirmEnd();
                                    Navigator.of(context).pop();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.bg,
                              disabledBackgroundColor: AppColors.accent,
                              disabledForegroundColor: AppColors.bg,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(3),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Confirmar'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.accent : Colors.transparent,
        foregroundColor: selected ? AppColors.bg : AppColors.text,
        side: BorderSide(
          color: selected
              ? AppColors.accent
              : AppColors.text.withValues(alpha: 0.16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
