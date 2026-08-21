import 'package:flutter/material.dart';

/// Dashed rail that slides sideways forever and fades out at the right
/// edge — "sem fim, logo sem 100%": the tempo-corrido (spec 006) reading
/// for a rental with no fixed duration to measure a progress bar against
/// (design source: `specs/007-revisao-design-v3`, artboard 1e, `sc-rail`
/// keyframe).
class EndlessRail extends StatefulWidget {
  const EndlessRail({super.key, required this.color, this.height = 5});

  final Color color;
  final double height;

  @override
  State<EndlessRail> createState() => _EndlessRailState();
}

class _EndlessRailState extends State<EndlessRail> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0, 0.74, 1],
      ).createShader(rect),
      child: SizedBox(
        height: 14,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _RailPainter(color: widget.color, phase: _c.value, barHeight: widget.height),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({required this.color, required this.phase, required this.barHeight});

  final Color color;
  final double phase;
  final double barHeight;

  static const _dash = 9.0;
  static const _period = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final y = (size.height - barHeight) / 2;
    RRect rrect(double x) => RRect.fromRectAndRadius(Rect.fromLTWH(x, y, _dash, barHeight), const Radius.circular(2.5));
    final offset = phase * _period;
    for (double x = -_period + offset; x < size.width; x += _period) {
      canvas.drawRRect(rrect(x), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RailPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color || oldDelegate.barHeight != barHeight;
}
