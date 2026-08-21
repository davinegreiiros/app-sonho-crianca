import 'package:flutter/material.dart';

/// Continuous opacity pulse (1 ↔ [minOpacity], ease-in-out, reversing),
/// matching the design's `sc-tick` keyframe. Used for the "aguardando
/// confirmação" status dot on the Pix cupom (spec 007-revisao-design-v3).
class Pulse extends StatefulWidget {
  const Pulse({
    super.key,
    required this.child,
    this.minOpacity = 0.25,
    this.period = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final double minOpacity;
  final Duration period;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Opacity(opacity: 1 - (1 - widget.minOpacity) * t, child: child);
      },
    );
  }
}
