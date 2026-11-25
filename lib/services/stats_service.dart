import '../core/utils/dates.dart';
import '../models/activity.dart';

class WeekBar {
  const WeekBar({required this.start, required this.distanceM});

  final DateTime start;
  final double distanceM;
}

class StatsSummary {
  const StatsSummary({
    required this.count,
    required this.totalDistanceM,
    required this.totalDurationS,
    required this.weekCount,
    required this.weekDistanceM,
    required this.weekDurationS,
    required this.longest,
    required this.weeks,
  });

  final int count;
  final double totalDistanceM;
  final int totalDurationS;
  final int weekCount;
  final double weekDistanceM;
  final int weekDurationS;
  final Activity? longest;
  final List<WeekBar> weeks;

  static const int weekBarCount = 8;

  int goalPercent(int goalKm) {
    if (goalKm <= 0) return 0;
    return (weekDistanceM / (goalKm * 1000) * 100).floor();
  }

  double goalProgress(int goalKm) {
    if (goalKm <= 0) return 0;
    final fraction = weekDistanceM / (goalKm * 1000);
    if (fraction < 0) return 0;
    return fraction > 1 ? 1 : fraction;
  }

  bool goalReached(int goalKm) => goalKm > 0 && weekDistanceM >= goalKm * 1000;

  static StatsSummary from(List<Activity> list, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final thisWeek = Dates.startOfWeek(today);

    var totalDistance = 0.0;
    var totalDuration = 0;
    var weekCount = 0;
    var weekDistance = 0.0;
    var weekDuration = 0;
    Activity? longest;
    final perWeek = List<double>.filled(weekBarCount, 0);

    for (final a in list) {
      totalDistance += a.distanceM;
      totalDuration += a.durationS;
      if (longest == null || a.distanceM > longest.distanceM) {
        longest = a;
      }

      final aWeek = Dates.startOfWeek(a.startTime);
      final weeksAgo = (thisWeek.difference(aWeek).inHours / 24 / 7).round();

      if (weeksAgo == 0) {
        weekCount += 1;
        weekDistance += a.distanceM;
        weekDuration += a.durationS;
      }
      if (weeksAgo >= 0 && weeksAgo < weekBarCount) {
        perWeek[weekBarCount - 1 - weeksAgo] += a.distanceM;
      }
    }

    final weeks = List<WeekBar>.generate(weekBarCount, (i) {
      final back = weekBarCount - 1 - i;
      return WeekBar(
        start: DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * back),
        distanceM: perWeek[i],
      );
    });

    return StatsSummary(
      count: list.length,
      totalDistanceM: totalDistance,
      totalDurationS: totalDuration,
      weekCount: weekCount,
      weekDistanceM: weekDistance,
      weekDurationS: weekDuration,
      longest: longest,
      weeks: weeks,
    );
  }
}
