import 'activity_type.dart';

class AppSettings {
  const AppSettings({
    this.defaultType = ActivityType.run,
    this.simulateByDefault = false,
    this.weeklyGoalKm = defaultWeeklyGoalKm,
  });

  static const int minWeeklyGoalKm = 5;
  static const int maxWeeklyGoalKm = 200;
  static const int weeklyGoalStepKm = 5;
  static const int defaultWeeklyGoalKm = 20;
  final ActivityType defaultType;
  final bool simulateByDefault;
  final int weeklyGoalKm;

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
