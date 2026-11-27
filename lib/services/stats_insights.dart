import '../core/utils/dates.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';

// Menambahkan statistik kecepatan rata-rata, streak dan sebaran per hari
// serta menambahkan rekor pribadi.
class StatsInsights {
  const StatsInsights({
    required this.avgSpeedMps,
    required this.currentStreak,
    required this.longestStreak,
    required this.perWeekday,
    required this.longestDuration,
    required this.fastestByType,
    required this.distanceByType,
  });

  // Kecepatan rata-rata (meter per detik): total jarak / total waktu.
  // 0 bila kosong. Pace (detik per km) = 1000 / nilai ini, km/jam = nilai * 3.6.
  // Paling bermakna bila daftar hanya berisi satu jenis aktivitas.
  final double avgSpeedMps;

  // Hari berturut-turut yang berakhir hari ini (atau kemarin).
  final int currentStreak;

  // Rangkaian hari berturut-turut terpanjang.
  final int longestStreak;

  // Jumlah aktivitas per hari, 7 elemen: Senin sampai Minggu.
  final List<int> perWeekday;

  // Aktivitas dengan durasi terlama.
  final Activity? longestDuration;

  // Aktivitas tercepat untuk tiap jenis (jenis yang tidak ada tidak muncul).
  final Map<ActivityType, Activity> fastestByType;

  // Total jarak (meter) per jenis aktivitas, jenis tanpa aktivitas tidak ada.
  final Map<ActivityType, double> distanceByType;

  static StatsInsights from(List<Activity> list, {DateTime? now}) {
    final today = Dates.startOfDay(now ?? DateTime.now());

    var distance = 0.0;
    var duration = 0;
    final perWeekday = List<int>.filled(7, 0);
    Activity? longestDuration;
    final fastest = <ActivityType, Activity>{};
    final byType = <ActivityType, double>{};

    for (final a in list) {
      distance += a.distanceM;
      duration += a.durationS;
      byType[a.type] = (byType[a.type] ?? 0) + a.distanceM;
      perWeekday[a.startTime.weekday - 1] += 1;

      if (longestDuration == null || a.durationS > longestDuration.durationS) {
        longestDuration = a;
      }
      if (a.distanceM > 0 && a.durationS > 0) {
        final best = fastest[a.type];
        if (best == null ||
            a.distanceM / a.durationS > best.distanceM / best.durationS) {
          fastest[a.type] = a;
        }
      }
    }

    // Streak: hitung dari hari-hari unik yang punya aktivitas.
    final days = {for (final a in list) Dates.startOfDay(a.startTime)}.toList()
      ..sort();
    var longest = 0;
    var run = 0;
    DateTime? prev;
    for (final d in days) {
      final consecutive =
          prev != null && d == DateTime(prev.year, prev.month, prev.day + 1);
      run = consecutive ? run + 1 : 1;
      if (run > longest) longest = run;
      prev = d;
    }

    // `run` sekarang = panjang rangkaian yang berakhir di hari terakhir.
    var current = 0;
    if (days.isNotEmpty) {
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      if (days.last == today || days.last == yesterday) current = run;
    }

    return StatsInsights(
      avgSpeedMps: duration > 0 ? distance / duration : 0,
      currentStreak: current,
      longestStreak: longest,
      perWeekday: perWeekday,
      longestDuration: longestDuration,
      fastestByType: fastest,
      distanceByType: byType,
    );
  }
}