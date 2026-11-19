import 'package:flutter/material.dart';

import '../../models/activity_type.dart';

/// Warna resmi Bootstrap 5.3.
class BsColors {
  BsColors._();

  static const Color primary = Color(0xFF0D6EFD);
  static const Color secondary = Color(0xFF6C757D);
  static const Color success = Color(0xFF198754);
  static const Color danger = Color(0xFFDC3545);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF0DCAF0);
  static const Color light = Color(0xFFF8F9FA);
  static const Color dark = Color(0xFF212529);
  static const Color orange = Color(0xFFFD7E14);
  static const Color purple = Color(0xFF6F42C1);

  static const Color body = Color(0xFF212529); // warna teks
  static const Color muted = Color(0xFF6C757D); // teks redup
  static const Color border = Color(0xFFDEE2E6); // garis pinggir
  static const Color background = Color(0xFFF8F9FA); // latar halaman
  static const Color focus = Color(0xFF86B7FE); // pinggir input saat fokus
}

/// Radius sudut Bootstrap.
class BsRadius {
  BsRadius._();

  static const double sm = 4; // .25rem
  static const double md = 6; // .375rem (default Bootstrap)
  static const double lg = 8; // .5rem
  static const double xl = 16; // 1rem
}

/// Varian warna, seperti btn-primary, alert-danger, badge bg-success, dst.
enum BsVariant {
  primary,
  secondary,
  success,
  danger,
  warning,
  info,
  light,
  dark,
}

extension BsVariantStyle on BsVariant {
  /// Warna solid (tombol dan badge).
  Color get color => switch (this) {
    BsVariant.primary => BsColors.primary,
    BsVariant.secondary => BsColors.secondary,
    BsVariant.success => BsColors.success,
    BsVariant.danger => BsColors.danger,
    BsVariant.warning => BsColors.warning,
    BsVariant.info => BsColors.info,
    BsVariant.light => BsColors.light,
    BsVariant.dark => BsColors.dark,
  };

  /// Warna teks di atas warna solid.
  Color get onColor => switch (this) {
    BsVariant.warning || BsVariant.info || BsVariant.light => BsColors.dark,
    _ => Colors.white,
  };

  /// Latar lembut (alert).
  Color get subtleBg => switch (this) {
    BsVariant.primary => const Color(0xFFCFE2FF),
    BsVariant.secondary => const Color(0xFFE2E3E5),
    BsVariant.success => const Color(0xFFD1E7DD),
    BsVariant.danger => const Color(0xFFF8D7DA),
    BsVariant.warning => const Color(0xFFFFF3CD),
    BsVariant.info => const Color(0xFFCFF4FC),
    BsVariant.light => const Color(0xFFFCFCFD),
    BsVariant.dark => const Color(0xFFCED4DA),
  };

  /// Garis pinggir lembut (alert).
  Color get subtleBorder => switch (this) {
    BsVariant.primary => const Color(0xFF9EC5FE),
    BsVariant.secondary => const Color(0xFFC4C8CB),
    BsVariant.success => const Color(0xFFA3CFBB),
    BsVariant.danger => const Color(0xFFF1AEB5),
    BsVariant.warning => const Color(0xFFFFE69C),
    BsVariant.info => const Color(0xFF9EEAF9),
    BsVariant.light => const Color(0xFFE9ECEF),
    BsVariant.dark => const Color(0xFFADB5BD),
  };

  /// Warna teks pekat (alert).
  Color get emphasis => switch (this) {
    BsVariant.primary => const Color(0xFF052C65),
    BsVariant.secondary => const Color(0xFF2B2F32),
    BsVariant.success => const Color(0xFF0A3622),
    BsVariant.danger => const Color(0xFF58151C),
    BsVariant.warning => const Color(0xFF664D03),
    BsVariant.info => const Color(0xFF055160),
    BsVariant.light => const Color(0xFF495057),
    BsVariant.dark => const Color(0xFF141619),
  };
}

/// Ikon dan warna tiap jenis aktivitas. Dipisah dari enum [ActivityType]
/// supaya model data tidak bergantung pada Flutter.
extension ActivityTypeStyle on ActivityType {
  IconData get icon => switch (this) {
    ActivityType.run => Icons.directions_run,
    ActivityType.ride => Icons.directions_bike,
    ActivityType.walk => Icons.directions_walk,
  };

  Color get color => switch (this) {
    ActivityType.run => BsColors.primary,
    ActivityType.ride => BsColors.success,
    ActivityType.walk => BsColors.orange,
  };
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: BsColors.primary).copyWith(
      primary: BsColors.primary,
      onPrimary: Colors.white,
      secondary: BsColors.secondary,
      onSecondary: Colors.white,
      error: BsColors.danger,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: BsColors.body,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: BsColors.background,
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFCFE2FF),
      ),
    );
  }
}
