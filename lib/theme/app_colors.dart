import 'package:flutter/material.dart';

/// Color tokens ported from the Claude Design "Broadsheet" design system
/// used by the Sonho de Criança project (`_ds/.../styles.css`).
class AppColors {
  AppColors._();

  static const bg = Color(0xFFF3F2F2);
  static const surface = Color(0xFFEAE9E9);
  static const text = Color(0xFF201E1D);
  static const accent = Color(0xFF0088B0);
  static const accent2 = Color(0xFFD6006C);
  static const divider = Color(0x29201E1D); // 16% mix

  // Cyan (accent) ramp
  static const accent100 = Color(0xFFE9F8FF);
  static const accent200 = Color(0xFFCBEEFF);
  static const accent700 = Color(0xFF006786);
  static const accent900 = Color(0xFF0A303E);

  // Magenta (accent-2) ramp
  static const accent2_100 = Color(0xFFFFF1F4);
  static const accent2_200 = Color(0xFFFFDEE6);
  static const accent2_700 = Color(0xFFAA0B56);
  static const accent2_900 = Color(0xFF4B1528);

  // Process yellow (print ink, decorative only)
  static const processYellow = Color(0xFFEDBB00);

  // Logo mark gradient (pink -> orange -> yellow).
  static const logoPink = Color(0xFFE83E8C);
  static const logoOrange = Color(0xFFFF8A3D);
  static const logoYellow = Color(0xFFFFC93D);

  // Modal backdrop veil (design source: color-mix(in srgb, #2d2b2b 50%, transparent)).
  static const overlayScrim = Color(0xFF2D2B2B);
  static const yellowTint = Color(0xFFF5E9C2); // ~24% mix over bg
  static const yellowFg = Color(0xFF7A5F00);
  static const yellowFgDark = Color(0xFF4A3A00);

  // Status colors (rental countdown)
  static const statusOk = Color(0xFF2F7D52);
  static const statusWarn = Color(0xFFB98900);
  static const statusUrgent = Color(0xFF946B00);

  // CMY "ink" per toy, matching the three brand hues.
  static const cyanTint = accent200;
  static const cyanFg = accent700;
  static const cyanDot = accent;

  static const magentaTint = accent2_200;
  static const magentaFg = accent2_700;
  static const magentaDot = accent2;

  static const yellowDot = processYellow;

  // Neutral "Outro" category ink (specs/007-revisao-design-v3): fg over
  // `surface`, no dedicated tint — reuses `surface` itself as background.
  static const neutralFg = Color(0xFF605D5D);
}

/// One of the three CMY "inks" a toy is tagged with, driving its tint colors
/// across cards, tags and chart dots.
enum ToyInk { cyan, magenta, yellow }

extension ToyInkColors on ToyInk {
  Color get tint => switch (this) {
    ToyInk.cyan => AppColors.cyanTint,
    ToyInk.magenta => AppColors.magentaTint,
    ToyInk.yellow => AppColors.yellowTint,
  };

  Color get fg => switch (this) {
    ToyInk.cyan => AppColors.cyanFg,
    ToyInk.magenta => AppColors.magentaFg,
    ToyInk.yellow => AppColors.yellowFg,
  };

  Color get dot => switch (this) {
    ToyInk.cyan => AppColors.cyanDot,
    ToyInk.magenta => AppColors.magentaDot,
    ToyInk.yellow => AppColors.yellowDot,
  };
}
