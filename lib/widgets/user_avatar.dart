import 'package:flutter/material.dart';

import '../core/theme/bootstrap_theme.dart';

/// Avatar bulat berisi huruf pertama nama.
/// Tanpa foto, jadi tidak butuh penyimpanan file.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.radius = 20});

  final String name;
  final double radius;

  static const List<Color> _palette = [
    BsColors.primary,
    BsColors.success,
    BsColors.danger,
    BsColors.secondary,
    BsColors.dark,
    BsColors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    final seed = trimmed.codeUnits.fold<int>(0, (sum, c) => sum + c);

    return CircleAvatar(
      radius: radius,
      backgroundColor: _palette[seed % _palette.length],
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
