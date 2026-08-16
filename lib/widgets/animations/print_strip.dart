import 'package:flutter/material.dart';

/// The CMY tricolor strip "printing" itself in from the left on mount —
/// an animated width reveal, not a static bar.
class PrintStrip extends StatefulWidget {
  const PrintStrip({super.key, this.height = 3, this.duration = const Duration(milliseconds: 550)});

  final double height;
  final Duration duration;

  @override
  State<PrintStrip> createState() => _PrintStripState();
}

class _PrintStripState extends State<PrintStrip> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        return AnimatedBuilder(
          animation: curved,
          builder: (context, _) => Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: widget.height,
              width: fullWidth * curved.value,
              child: const Row(
                children: [
                  Expanded(child: ColoredBox(color: Color(0xFF0088B0))),
                  Expanded(child: ColoredBox(color: Color(0xFFD6006C))),
                  Expanded(child: ColoredBox(color: Color(0xFFEDBB00))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
