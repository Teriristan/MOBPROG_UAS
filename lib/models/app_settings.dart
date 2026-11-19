import 'activity_type.dart';

/// Pengaturan pengguna yang disimpan di perangkat (SharedPreferences).
///
/// Berbeda dengan data akun dan aktivitas di [LocalDb], pengaturan berlaku
/// untuk perangkat ini, siapa pun yang sedang masuk.
class AppSettings {
  const AppSettings({
    this.defaultType = ActivityType.run,
    this.simulateByDefault = false,
    this.weeklyGoalKm = defaultWeeklyGoalKm,
  });

  /// Batas dan langkah target mingguan (kilometer).
  static const int minWeeklyGoalKm = 5;
  static const int maxWeeklyGoalKm = 200;
  static const int weeklyGoalStepKm = 5;
  static const int defaultWeeklyGoalKm = 20;

  /// Jenis aktivitas yang terpilih saat layar Rekam dibuka.
  final ActivityType defaultType;

  /// Mode simulasi menyala sejak awal (uji coba tanpa bergerak).
  final bool simulateByDefault;

  /// Target jarak per minggu dalam kilometer.
  final int weeklyGoalKm;

  /// Menjepit [km] ke rentang yang diizinkan.
  static int clampGoal(int km) {
    if (km < minWeeklyGoalKm) return minWeeklyGoalKm;
    if (km > maxWeeklyGoalKm) return maxWeeklyGoalKm;
    return km;
  }

  AppSettings copyWith({
    ActivityType? defaultType,
    bool? simulateByDefault,
    int? weeklyGoalKm,
  }) {
    return AppSettings(
      defaultType: defaultType ?? this.defaultType,
      simulateByDefault: simulateByDefault ?? this.simulateByDefault,
      weeklyGoalKm: clampGoal(weeklyGoalKm ?? this.weeklyGoalKm),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.defaultType == defaultType &&
        other.simulateByDefault == simulateByDefault &&
        other.weeklyGoalKm == weeklyGoalKm;
  }

  @override
  int get hashCode => Object.hash(defaultType, simulateByDefault, weeklyGoalKm);

  @override
  String toString() =>
      'AppSettings(defaultType: ${defaultType.name}, '
      'simulateByDefault: $simulateByDefault, weeklyGoalKm: $weeklyGoalKm)';
}
