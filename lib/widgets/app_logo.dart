import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme/bootstrap_theme.dart';

/// Menampilkan logo dari assets/images/logo.png.
/// Kalau file belum ada, tampil ikon pengganti (tidak error).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppConstants.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.directions_run, size: size, color: BsColors.primary),
    );
  }
}
