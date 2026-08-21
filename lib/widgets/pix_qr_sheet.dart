import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/pix_payload.dart';
import '../state/app_state.dart';
import '../test_keys.dart';
import '../theme/app_colors.dart';
import 'animations/pressable.dart';

/// Shows the Pix QR (+ "copia e cola" text) for a rental's final price,
/// then lets the operator confirm the payment landed — same commit as
/// today's "Confirmar" (`AppState.confirmEnd`), just with the QR shown
/// first (spec 004-pix-qrcode).
class PixQrSheet extends StatelessWidget {
  const PixQrSheet({super.key, required this.rentalId});
  final String rentalId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rental = state.rentals.where((r) => r.id == rentalId).firstOrNull;
    if (rental == null) return const SizedBox.shrink();

    // `showPixQrStep()` already froze this the instant the QR step opened
    // (spec 004/006 fix: a tempo-corrido price keeps climbing every
    // second the QR is on screen) — reuse that exact value here so the
    // QR always encodes the same amount `confirmEnd()` ends up charging.
    final amount = state.endFrozenPrice ?? state.computeFinalPrice(rental);
    final settings = state.businessSettings;
    final payload = buildPixPayload(
      merchantName: settings.merchantName,
      merchantCity: settings.merchantCity,
      pixKey: settings.pixKey,
      amountCents: (amount * 100).round(),
    );

    // Same reasoning as `EndRentalDialog`: this can be shown through a
    // route (`showGeneralDialog`) with no `Material` ancestor of its own,
    // so it needs one to avoid the plain-`Text` fallback-style bug fixed
    // in specs/001-tema-layout-parity.
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: AppColors.bg, borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('Pagamento via Pix',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(state.fmtMoney(amount),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent)),
                const SizedBox(height: 16),
                // QR + payload box in their own scroll region: on a short
                // screen (or this dialog's own bounded height once it's
                // centered with 20px of padding all round) they're the
                // part that can legitimately not fit — better a short
                // scroll than a `RenderFlex` overflow clipping the buttons
                // below off-screen.
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          key: TestKeys.pixQrImage,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8)),
                          child: QrImageView(
                              data: payload,
                              size: 200,
                              backgroundColor: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Pix copia e cola',
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      AppColors.text.withValues(alpha: 0.7))),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            payload,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppColors.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Pressable(
                  child: TextButton.icon(
                    key: TestKeys.copyPixPayloadButton,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: payload));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Código Pix copiado.'),
                            duration: Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copiar código'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Pressable(
                    child: ElevatedButton(
                      key: TestKeys.pixQrDoneButton,
                      onPressed: () {
                        // `confirmEnd()` nulls `endingId` and notifies
                        // synchronously — `EndRentalDialog` (this sheet's
                        // parent) rebuilds right then and swaps this widget
                        // out, so `context` is a deactivated element by the
                        // time control returns here. Grab the `Navigator`
                        // first, while `context` is still good.
                        final navigator = Navigator.of(context);
                        state.confirmEnd();
                        navigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.bg,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Pagamento recebido, concluir'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
