import 'package:flutter/material.dart';

/// Continuous gentle vertical bounce (ease-in-out, reversing), matching
/// the design's `sc-bounce` keyframe. Used for the FAB and the header's
/// three status dots — pass [phase] (0..1) to offset each dot so they
/// bounce in a wave instead of in lockstep.
class Bouncy extends StatefulWidget {
  const Bouncy({
    super.key,
    required this.child,
    this.height = 4,
    this.period = const Duration(milliseconds: 1200),
    this.phase = 0,
    this.enabled = true,
  });

  final Widget child;
  final double height;
  final Duration period;
  final double phase;
  final bool enabled;

  @override
  State<Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<Bouncy> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _c.value = widget.phase;
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(offset: Offset(0, -widget.height * t), child: child);
      },
    );
  }
}
