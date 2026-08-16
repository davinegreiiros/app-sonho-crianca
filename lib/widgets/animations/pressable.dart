import 'package:flutter/material.dart';

/// Purely visual press/hover feedback: shrinks on press, grows a hair on
/// hover, optional tiny rotation wobble (used for toy icons). Uses
/// [Listener] (not [GestureDetector]) so it never steals the gesture
/// arena from the real button/InkWell it wraps — safe to drop around any
/// tappable widget without breaking its `onTap`/`onPressed`.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.pressScale = 0.96,
    this.hoverScale = 1.02,
    this.rotateOnHover = false,
  });

  final Widget child;
  final double pressScale;
  final double hoverScale;
  final bool rotateOnHover;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scale = _down ? widget.pressScale : (_hover ? widget.hoverScale : 1.0);
    final angle = widget.rotateOnHover && (_hover || _down) ? (_down ? -0.06 : 0.05) : 0.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedRotation(
            turns: angle,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
