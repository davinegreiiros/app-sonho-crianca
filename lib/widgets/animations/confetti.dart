import 'dart:math';

import 'package:flutter/material.dart';

/// A handful of small CMY-colored dots gently floating upward and looping,
/// laid decoratively over a card (e.g. the "faturado hoje" total). Purely
/// cosmetic — `IgnorePointer` so it never intercepts taps.
class FloatingConfetti extends StatefulWidget {
  const FloatingConfetti({super.key, this.count = 7});

  final int count;

  @override
  State<FloatingConfetti> createState() => _FloatingConfettiState();
}

class _FloatingConfettiState extends State<FloatingConfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))
    ..repeat();
  late final List<_Particle> _particles = List.generate(widget.count, (i) => _Particle(i, widget.count));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Stack(
              children: [
                for (final p in _particles) p.build(context, constraints.biggest, _c.value),
              ],
            ),
          );
        },
      ),
    );
  }
}

const _kConfettiColors = [Color(0xFF0088B0), Color(0xFFD6006C), Color(0xFFEDBB00)];

class _Particle {
  _Particle(int index, int total)
      : color = _kConfettiColors[index % _kConfettiColors.length],
        size = 4.0 + (index % 3) * 2,
        xFrac = (Random(index * 97).nextDouble()),
        phase = index / total;

  final Color color;
  final double size;
  final double xFrac;
  final double phase;

  Widget build(BuildContext context, Size area, double t) {
    final local = (t + phase) % 1.0;
    final y = area.height * (1 - local);
    final opacity = local < 0.15 ? local / 0.15 : (local > 0.85 ? (1 - local) / 0.15 : 1.0);
    return Positioned(
      left: area.width * xFrac,
      top: y,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0) * 0.55,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
