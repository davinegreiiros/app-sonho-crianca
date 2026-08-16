import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Toy illustration tile: `assets/images/toy-<imageKey>.png` on a tinted
/// CMY-ink backdrop — matching the design's `image-slot`. Falls back to a
/// generic glyph only if that asset is somehow missing.
class ToyIcon extends StatelessWidget {
  const ToyIcon({
    super.key,
    required this.imageKey,
    required this.ink,
    this.size = 44,
    this.radius = 10,
    this.fill = false,
  });

  final String imageKey;
  final ToyInk ink;
  final double size;
  final double radius;

  /// When true, the tile expands to fill its parent instead of being
  /// sized to [size].
  final bool fill;

  String get _asset => 'assets/images/toy-$imageKey.png';

  @override
  Widget build(BuildContext context) {
    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: fill ? double.infinity : size,
        height: fill ? double.infinity : size,
        color: ink.tint,
        child: Image.asset(
          _asset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(Icons.toys_rounded, color: ink.fg, size: size * 0.56),
          ),
        ),
      ),
    );
    return fill ? SizedBox.expand(child: tile) : tile;
  }
}
