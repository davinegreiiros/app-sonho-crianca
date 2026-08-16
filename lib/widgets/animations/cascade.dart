import 'package:flutter/material.dart';

/// Drives a staggered entrance for a list of items with a single shared
/// [AnimationController] sliced into per-item [Interval]s — the standard
/// Flutter "one controller, many intervals" stagger recipe. Own one of
/// these per screen (in `initState`, not `build`) so it doesn't restart
/// every time the screen rebuilds (e.g. from the 1s countdown ticker).
class CascadeController {
  CascadeController(
    TickerProvider vsync, {
    required int itemCount,
    this.staggerMs = 55,
    this.itemMs = 380,
  }) : controller = AnimationController(
          vsync: vsync,
          duration: Duration(
            milliseconds: itemCount <= 1 ? itemMs : staggerMs * (itemCount - 1) + itemMs,
          ),
        ) {
    controller.forward();
  }

  final AnimationController controller;
  final int staggerMs;
  final int itemMs;

  /// Wraps [child] with the fade/slide (or elastic pop, when [pop] is
  /// true) entrance for the item at [index].
  Widget item(int index, {required Widget child, bool pop = false, double slideY = 16}) {
    final totalMs = controller.duration!.inMilliseconds;
    final startMs = (staggerMs * index).clamp(0, totalMs);
    final endMs = (startMs + itemMs).clamp(0, totalMs);
    final start = totalMs == 0 ? 0.0 : startMs / totalMs;
    final end = (totalMs == 0 ? 1.0 : endMs / totalMs).clamp(start, 1.0);
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: pop ? Curves.easeOutBack : Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, c) {
        final v = curved.value;
        final opacity = v.clamp(0.0, 1.0);
        Widget result = Opacity(opacity: opacity, child: c);
        if (pop) {
          result = Transform.scale(scale: v.clamp(0.0, 1.3), child: result);
        } else {
          result = Transform.translate(offset: Offset(0, (1 - v) * slideY), child: result);
        }
        return result;
      },
    );
  }

  void dispose() => controller.dispose();
}
