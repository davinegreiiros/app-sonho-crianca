import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Rental countdown progress bar: a continuously scrolling diagonal
/// "barber pole" stripe in the status color over the filled portion, and
/// a slow opacity pulse (matching the design's `sc-pulse`) once the
/// rental runs overtime.
class StripedProgress extends StatefulWidget {
  const StripedProgress({
    super.key,
    required this.progress,
    required this.color,
    this.pulse = false,
    this.height = 5,
  });

  final double progress;
  final Color color;
  final bool pulse;
  final double height;

  @override
  State<StripedProgress> createState() => _StripedProgressState();
}

class _StripedProgressState extends State<StripedProgress> with TickerProviderStateMixin {
  late final AnimationController _stripe =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _stripe.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_stripe, _pulse]),
      builder: (context, _) {
        final opacity = widget.pulse ? (0.45 + 0.55 * (1 - _pulse.value)) : 1.0;
        return Opacity(
          opacity: opacity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: CustomPaint(
                painter: _StripePainter(
                  progress: widget.progress,
                  color: widget.color,
                  phase: _stripe.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter({required this.progress, required this.color, required this.phase});

  final double progress;
  final Color color;
  final double phase;

  static const _stripeWidth = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.text.withValues(alpha: 0.1));

    final fillWidth = size.width * progress.clamp(0.0, 1.0);
    if (fillWidth <= 0) return;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, fillWidth, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, fillWidth, size.height), Paint()..color = color.withValues(alpha: 0.55));

    final stripePaint = Paint()..color = color.withValues(alpha: 0.9);
    final period = _stripeWidth * 2;
    final offset = phase * period;
    final path = Path();
    for (double x = -size.height - period + offset; x < fillWidth + size.height; x += period) {
      path.moveTo(x, size.height);
      path.lineTo(x + size.height, 0);
      path.lineTo(x + size.height + _stripeWidth, 0);
      path.lineTo(x + _stripeWidth, size.height);
      path.close();
    }
    canvas.drawPath(path, stripePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.phase != phase;
}
