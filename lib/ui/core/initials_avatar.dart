import 'package:flutter/material.dart';

/// First letter of up to 2 words of [name], uppercase — `'Gustavo'` → `'G'`,
/// `'Ana Souza'` → `'AS'`, empty/blank → `'—'` (no monitor/child yet).
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '—';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// Solid-color circle with 1-2 initial letters — the monitor/child avatar
/// used across the posto screens (design source: `Revisao de Design v3`,
/// artboards 3a/3b).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.text, required this.background, required this.foreground, this.size = 38});

  final String text;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: background),
      child: Text(
        text,
        style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}
