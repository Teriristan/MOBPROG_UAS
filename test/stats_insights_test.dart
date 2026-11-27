import 'package:flutter_lokasi2/models/activity.dart';
import 'package:flutter_lokasi2/models/activity_type.dart';
import 'package:flutter_lokasi2/models/stats_period.dart';
import 'package:flutter_lokasi2/services/stats_insights.dart';
import 'package:flutter_lokasi2/services/stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

Activity _act(
  String id,
  ActivityType type,
  double distanceM,
  int durationS,
  DateTime start,
) {
  return Activity(
    id: id,
    userId: 'u',
    userName: 'U',
    title: id,
    type: type,
    distanceM: distanceM,
    durationS: durationS,
    startTime: start,
  );
}

void main() {
  // Selasa, 24 November 2026.
  final now = DateTime(2026, 11, 24, 10);

  List<Activity> onDays(List<int> days) => [
    for (final d in days)
      _act('d$d', ActivityType.run, 1000, 300, DateTime(2026, 11, d, 7)),
  ];

  group('StatsInsights', () {
    test('daftar kosong', () {
      final i = StatsInsights.from(const [], now: now);
      expect(i.avgSpeedMps, 0);
      expect(i.currentStreak, 0);
      expect(i.longestStreak, 0);
      expect(i.perWeekday, List<int>.filled(7, 0));
      expect(i.longestDuration, isNull);
      expect(i.fastestByType, isEmpty);
      expect(i.distanceByType, isEmpty);
    });

    test('streak berturut-turut sampai hari ini', () {
      final i = StatsInsights.from(onDays([22, 23, 24]), now: now);
      expect(i.currentStreak, 3);
      expect(i.longestStreak, 3);
    });

    test('streak terpanjang terpisah dari streak sekarang', () {
      final i = StatsInsights.from(onDays([18, 19, 20, 23, 24]), now: now);
      expect(i.longestStreak, 3);
      expect(i.currentStreak, 2);
    });

    test('streak masih hidup bila terakhir aktif kemarin', () {
      final i = StatsInsights.from(onDays([23]), now: now);
      expect(i.currentStreak, 1);
    });

    test('streak putus bila terakhir aktif 2 hari lalu', () {
      final i = StatsInsights.from(onDays([22]), now: now);
      expect(i.currentStreak, 0);
      expect(i.longestStreak, 1);
    });

    test('dua aktivitas di hari yang sama dihitung satu hari streak', () {
      final list = [
        _act('a', ActivityType.run, 1000, 300, DateTime(2026, 11, 24, 6)),
        _act('b', ActivityType.run, 1000, 300, DateTime(2026, 11, 24, 18)),
      ];
      expect(StatsInsights.from(list, now: now).currentStreak, 1);
    });

    test('sebaran per hari (Senin = indeks 0)', () {
      // 23 Nov = Senin, 24 Nov = Selasa.
      final i = StatsInsights.from(onDays([23, 24, 24]), now: now);
      expect(i.perWeekday, [1, 2, 0, 0, 0, 0, 0]);
    });

    test('kecepatan rata-rata = total jarak / total waktu', () {
      final list = [
        _act('a', ActivityType.run, 1000, 300, DateTime(2026, 11, 23)),
        _act('b', ActivityType.run, 3000, 900, DateTime(2026, 11, 24)),
      ];
      expect(
        StatsInsights.from(list, now: now).avgSpeedMps,
        closeTo(4000 / 1200, 1e-9),
      );
    });

    test('durasi terlama dan tercepat per jenis', () {
      final slow = _act('slow', ActivityType.run, 1000, 300, DateTime(2026, 11, 22));
      final fast = _act('fast', ActivityType.run, 5000, 1200, DateTime(2026, 11, 23));
      final ride = _act('ride', ActivityType.ride, 10000, 1800, DateTime(2026, 11, 24));
      final i = StatsInsights.from([slow, fast, ride], now: now);

      expect(i.longestDuration?.id, 'ride');
      expect(i.fastestByType[ActivityType.run]?.id, 'fast');
      expect(i.fastestByType[ActivityType.ride]?.id, 'ride');
      expect(i.fastestByType.containsKey(ActivityType.walk), isFalse);
    });

    test('jarak per jenis', () {
      final list = [
        _act('a', ActivityType.run, 1000, 300, DateTime(2026, 11, 22)),
        _act('b', ActivityType.run, 2000, 600, DateTime(2026, 11, 23)),
        _act('c', ActivityType.ride, 5000, 900, DateTime(2026, 11, 24)),
      ];
      final i = StatsInsights.from(list, now: now);

      expect(i.distanceByType[ActivityType.run], 3000);
      expect(i.distanceByType[ActivityType.ride], 5000);
      expect(i.distanceByType.containsKey(ActivityType.walk), isFalse);
    });
  });

  group('StatsFilter', () {
    final list = [
      _act('week', ActivityType.run, 1000, 300, DateTime(2026, 11, 24)),
      _act('month', ActivityType.ride, 5000, 900, DateTime(2026, 11, 22)),
      _act('old', ActivityType.walk, 500, 400, DateTime(2026, 10, 30)),
    ];

    List<String> ids(StatsPeriod p, [ActivityType? t]) => StatsFilter.apply(
      list,
      period: p,
      type: t,
      now: now,
    ).map((a) => a.id).toList();

    test('rentang waktu', () {
      expect(ids(StatsPeriod.week), ['week']);
      expect(ids(StatsPeriod.month), ['week', 'month']);
      expect(ids(StatsPeriod.all), ['week', 'month', 'old']);
    });

    test('jenis aktivitas', () {
      expect(ids(StatsPeriod.all, ActivityType.ride), ['month']);
      expect(ids(StatsPeriod.week, ActivityType.ride), isEmpty);
    });
  });
}