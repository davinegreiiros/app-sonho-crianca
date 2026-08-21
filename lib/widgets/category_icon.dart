import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/toy.dart';

/// Phosphor-duotone glyph for a [ToyCategory] (`assets/icons/category/`),
/// retinted to [color] via `BlendMode.srcIn` — the SVG's own opacity-0.25
/// fill vs full-opacity stroke stays intact, so one tint still reads as
/// two-tone (spec 007-revisao-design-v3, artboard 1b).
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.category, required this.color, this.size = 13});

  final ToyCategory category;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      category.iconAsset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
