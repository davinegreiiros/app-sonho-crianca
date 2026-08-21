import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/pix_payload.dart';
import '../state/app_state.dart';
import '../test_keys.dart';
import '../theme/app_colors.dart';
import 'animations/pressable.dart';
import 'animations/print_strip.dart';
import 'animations/pulse.dart';

/// Shows the Pix QR (+ "copia e cola" text) for a rental's final price,
/// then lets the operator confirm the payment landed — same commit as
/// today's "Confirmar" (`AppState.confirmEnd`), just with the QR shown
/// first (spec 004-pix-qrcode). Redressed as a cash-register "cupom"
/// (CMY ink stripe, perforated-edge trim, doc number) in spec
/// 007-revisao-design-v3, artboard 1c — same outer container shape as
/// before (`Material > Center > Padding > Container > Column`), only the
/// content inside changed, so the pop-in transition's layout stays as
/// proven-stable as the rest of the app's dialogs. The "copiar" and
/// "trocar forma"/"concluir" buttons keep the exact `Row`/`Expanded`/
/// `Pressable` shapes already proven stable elsewhere in this file and in
/// `EndRentalDialog` — a `CrossAxisAlignment.stretch` Row around a fixed-
/// height `Pressable(ElevatedButton)` was tried here and made
/// `WidgetTester.tap` intermittently hit-test a not-yet-laid-out
/// `RenderBox` (`flutter test` "Cannot hit test a render box with no
/// size"); don't reintroduce that combination.
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
    final toy = state.toyById(rental.toyId);
    final doc = _sanitizedDoc(rental.id);
    final payload = buildPixPayload(
      merchantName: settings.merchantName,
      merchantCity: settings.merchantCity,
      pixKey: settings.pixKey,
      amountCents: (amount * 100).round(),
      txid: doc,
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
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _PerforationRow(),
                const SizedBox(height: 10),
                const PrintStrip(height: 3),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      'COBRANÇA PIX',
                      style: TextStyle(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: AppColors.accent700),
                    ),
                    const Spacer(),
                    Text(
                      'Nº $doc',
                      style: TextStyle(fontSize: 10, letterSpacing: 1, color: AppColors.text.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${toy.name} · ${rental.childName}',
                  style: TextStyle(fontSize: 12.5, color: AppColors.text.withValues(alpha: 0.7)),
                ),
                Text(
                  state.fmtMoney(amount),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.05),
                ),
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
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                          ),
                          child: QrImageView(
                            data: payload,
                            size: 190,
                            backgroundColor: Colors.white,
                            // `qr_flutter` paints every finder eye with a
                            // single color — the design's ciano/magenta/
                            // amarelo tri-color eyes aren't reproducible
                            // here (documented deviation, spec.md).
                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.accent2_700),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'PIX COPIA E COLA',
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            payload,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppColors.text),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Pressable(
                          child: TextButton.icon(
                            key: TestKeys.copyPixPayloadButton,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: payload));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Código Pix copiado.'), duration: Duration(seconds: 2)),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Copiar código'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Decorative-only "aguardando confirmação": the app
                        // stays 100% local/offline (baseline de segurança,
                        // specs/002-seguranca-dados) — this never polls a
                        // bank, it just signals to the operator that the QR
                        // is up while they wait for the customer to pay.
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                          decoration: BoxDecoration(color: AppColors.accent100, borderRadius: BorderRadius.circular(2)),
                          child: Row(
                            children: [
                              Pulse(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Aguardando confirmação no app do banco',
                                  style: TextStyle(fontSize: 12, color: AppColors.accent900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Pressable(
                        child: OutlinedButton(
                          key: TestKeys.pixTrocarFormaButton,
                          onPressed: () => state.hidePixQrStep(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.text,
                            side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Trocar forma'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Recebido, concluir'),
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

/// Turns a rental id into the cupom's "nº de documento" and the payload's
/// EMV `txid` field — alphanumeric, uppercase, capped at 25 chars (the
/// field's max length per the Pix BR Code spec).
String _sanitizedDoc(String rentalId) {
  final alnum = rentalId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  if (alnum.isEmpty) return '000';
  return alnum.length > 25 ? alnum.substring(0, 25) : alnum;
}

/// Thin row of dots mimicking a perforated ticket edge (design source,
/// artboard 1c) — a plain in-flow decoration (not a clip on the card
/// itself), so it can't affect the card's own layout/hit-testing.
class _PerforationRow extends StatelessWidget {
  const _PerforationRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 10.0;
          final count = (constraints.maxWidth / spacing).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < count; i++)
                Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.divider, shape: BoxShape.circle)),
            ],
          );
        },
      ),
    );
  }
}
