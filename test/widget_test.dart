import 'dart:convert';

import 'package:flutter_lokasi2/core/utils/dates.dart';
import 'package:flutter_lokasi2/core/utils/formatters.dart';
import 'package:flutter_lokasi2/core/utils/route_utils.dart';
import 'package:flutter_lokasi2/models/activity.dart';
import 'package:flutter_lokasi2/models/activity_type.dart';
import 'package:flutter_lokasi2/services/leaderboard_service.dart';
import 'package:flutter_lokasi2/services/stats_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart' show LatLng;

Activity _activity({
  required String id,
  required String userId,
  required String userName,
  required ActivityType type,
  required double distanceM,
  required int durationS,
  required DateTime startTime,
}) {
  return Activity(
    id: id,
    userId: userId,
    userName: userName,
    title: 'Aktivitas $id',
    type: type,
    distanceM: distanceM,
    durationS: durationS,
    startTime: startTime,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  group('Fmt', () {
    test('duration menampilkan menit:detik atau jam:menit:detik', () {
      expect(Fmt.duration(725), '12:05');
      expect(Fmt.duration(3725), '1:02:05');
    });

    test('pace dalam menit per km', () {
      expect(Fmt.pace(5000, 1500), '5:00');
      expect(Fmt.pace(5, 10), '--:--');
    });

    test('km memakai koma sebagai pemisah desimal', () {
      expect(Fmt.km(5230), '5,23');
    });

    test('speed dalam km per jam', () {
      expect(Fmt.speed(10000, 3600), '10,0');
    });

    test('fileSize memakai satuan B, KB, atau MB', () {
      expect(Fmt.fileSize(0), '0 B');
      expect(Fmt.fileSize(1023), '1023 B');
      expect(Fmt.fileSize(1024), '1,0 KB');
      expect(Fmt.fileSize(1536), '1,5 KB');
      expect(Fmt.fileSize(1024 * 1024), '1,0 MB');
      expect(Fmt.fileSize(5 * 1024 * 1024 + 512 * 1024), '5,5 MB');
      // Di bawah 1 MB tetap KB walau angkanya sudah di atas 1000.
      expect(Fmt.fileSize(1030000), '1005,9 KB');
    });
  });

  group('ActivityType', () {
    test('fromKey membaca teks dari database', () {
      expect(ActivityType.fromKey('ride'), ActivityType.ride);
      expect(ActivityType.fromKey('walk'), ActivityType.walk);
      expect(ActivityType.fromKey(null), ActivityType.run);
      expect(ActivityType.fromKey('tidak-dikenal'), ActivityType.run);
    });

    test('hanya sepeda yang memakai kecepatan', () {
      expect(ActivityType.ride.usesSpeed, isTrue);
      expect(ActivityType.run.usesSpeed, isFalse);
      expect(ActivityType.walk.usesSpeed, isFalse);
    });
  });

  group('Dates', () {
    test('awal minggu adalah hari Senin', () {
      // 4 Nov 2026 jatuh pada hari Rabu.
      expect(
        Dates.startOfWeek(DateTime(2026, 11, 4, 15, 30)),
        DateTime(2026, 11, 2),
      );
    });

    test('awal bulan adalah tanggal 1', () {
      expect(Dates.startOfMonth(DateTime(2026, 11, 20)), DateTime(2026, 11, 1));
    });
  });

  group('RouteUtils.simplify', () {
    final points = List<LatLng>.generate(2000, (i) => LatLng(i * 0.00001, 0.0));

    test('membatasi jumlah titik dan mempertahankan ujung rute', () {
      final result = RouteUtils.simplify(points);
      expect(result.length, 800);
      expect(result.first, points.first);
      expect(result.last, points.last);
    });

    test('rute pendek tidak diubah', () {
      final short = points.take(10).toList();
      expect(RouteUtils.simplify(short), short);
    });
  });

  group('LeaderboardService.rank', () {
    final when = DateTime(2026, 11, 4, 8);
    final data = <Activity>[
      _activity(
        id: '1',
        userId: 'a',
        userName: 'Ani',
        type: ActivityType.run,
        distanceM: 5000,
        durationS: 1500,
        startTime: when,
      ),
      _activity(
        id: '2',
        userId: 'a',
        userName: 'Ani',
        type: ActivityType.walk,
        distanceM: 3000,
        durationS: 2400,
        startTime: when,
      ),
      _activity(
        id: '3',
        userId: 'b',
        userName: 'Budi',
        type: ActivityType.ride,
        distanceM: 6000,
        durationS: 1200,
        startTime: when,
      ),
    ];

    test('menjumlah jarak per pengguna dan mengurutkan dari yang terjauh', () {
      final ranking = LeaderboardService.rank(data);
      expect(ranking.map((e) => e.userId).toList(), ['a', 'b']);
      expect(ranking.first.distanceM, 8000);
      expect(ranking.first.count, 2);
      expect(ranking.first.durationS, 3900);
    });

    test('filter jenis aktivitas', () {
      final ranking = LeaderboardService.rank(data, type: ActivityType.ride);
      expect(ranking.length, 1);
      expect(ranking.single.userId, 'b');
    });

    test('filter pengguna tertentu', () {
      final ranking = LeaderboardService.rank(data, onlyUsers: {'b'});
      expect(ranking.length, 1);
      expect(ranking.single.userName, 'Budi');
    });
  });

  group('StatsSummary.from', () {
    // Rabu 4 Nov 2026, jadi "minggu ini" dimulai Senin 2 Nov 2026.
    final now = DateTime(2026, 11, 4, 12);
    final list = <Activity>[
      _activity(
        id: '1',
        userId: 'a',
        userName: 'Ani',
        type: ActivityType.run,
        distanceM: 5000,
        durationS: 1500,
        startTime: DateTime(2026, 11, 3, 6), // minggu ini
      ),
      _activity(
        id: '2',
        userId: 'a',
        userName: 'Ani',
        type: ActivityType.run,
        distanceM: 3000,
        durationS: 1000,
        startTime: DateTime(2026, 10, 28, 6), // satu minggu lalu
      ),
      _activity(
        id: '3',
        userId: 'a',
        userName: 'Ani',
        type: ActivityType.ride,
        distanceM: 12000,
        durationS: 4000,
        startTime: DateTime(2026, 8, 1, 6), // lebih dari 8 minggu lalu
      ),
    ];
    final summary = StatsSummary.from(list, now: now);

    test('total keseluruhan', () {
      expect(summary.count, 3);
      expect(summary.totalDistanceM, 20000);
      expect(summary.totalDurationS, 6500);
    });

    test('ringkasan minggu ini', () {
      expect(summary.weekCount, 1);
      expect(summary.weekDistanceM, 5000);
      expect(summary.weekDurationS, 1500);
    });

    test('delapan batang mingguan, yang terakhir adalah minggu ini', () {
      expect(summary.weeks.length, 8);
      expect(summary.weeks.last.distanceM, 5000);
      expect(summary.weeks[6].distanceM, 3000);
      expect(summary.weeks.first.distanceM, 0);
    });

    test('aktivitas terjauh', () {
      expect(summary.longest?.id, '3');
    });

    test('target mingguan: persen, batang progres, dan tercapai', () {
      // Minggu ini baru 5 km.
      expect(summary.goalPercent(20), 25);
      expect(summary.goalProgress(20), 0.25);
      expect(summary.goalReached(20), isFalse);

      // Tepat di target dan melebihi target.
      expect(summary.goalPercent(5), 100);
      expect(summary.goalProgress(5), 1);
      expect(summary.goalReached(5), isTrue);
      expect(summary.goalPercent(2), 250);
      expect(summary.goalProgress(2), 1);
      expect(summary.goalReached(2), isTrue);
    });

    test('persen target dibulatkan ke bawah', () {
      expect(summary.goalPercent(7), 71); // 5 / 7 = 71,4%
      expect(summary.goalPercent(6), 83); // 83,3%
      expect(summary.goalPercent(3), 166); // 166,7%, bukan 167
    });

    test('target nol tidak menyebabkan pembagian dengan nol', () {
      expect(summary.goalPercent(0), 0);
      expect(summary.goalProgress(0), 0);
      expect(summary.goalReached(0), isFalse);
    });
  });

  group('RouteUtils.encode / decode', () {
    test('bolak-balik pada ketelitian 0,00001 derajat', () {
      const route = <LatLng>[
        LatLng(-6.17540, 106.82720),
        LatLng(-6.17551, 106.82733),
      ];
      final raw = RouteUtils.encode(route);
      expect(raw, <int>[-617540, 10682720, -617551, 10682733]);
      expect(RouteUtils.decode(raw), route);
    });

    test('rute kosong tetap kosong', () {
      expect(RouteUtils.encode(const <LatLng>[]), isEmpty);
      expect(RouteUtils.decode(const <int>[]), isEmpty);
    });

    test('decode mengabaikan data rusak', () {
      expect(RouteUtils.decode(null), isEmpty);
      expect(RouteUtils.decode('bukan daftar'), isEmpty);
      // Angka terakhir tanpa pasangan dibuang.
      expect(RouteUtils.decode(<Object>[1, 2, 3]).length, 1);
      // Pasangan yang bukan angka dilewati.
      expect(RouteUtils.decode(<Object>[1, 'x', 3, 4]).length, 1);
    });
  });

  group('Activity JSON', () {
    final original = Activity(
      id: 'x1',
      userId: 'u1',
      userName: 'Ani',
      title: 'Lari Pagi',
      type: ActivityType.ride,
      description: 'Cerah',
      distanceM: 12345.5,
      durationS: 3600,
      startTime: DateTime(2026, 11, 3, 6, 30),
      route: const <LatLng>[LatLng(-6.2, 106.8), LatLng(-6.21, 106.81)],
      kudosBy: const <String>['u2', 'u3'],
      commentsCount: 7,
    );

    test('toJson lalu fromJson menghasilkan data yang sama', () {
      final text = jsonEncode(original.toJson());
      final back = Activity.fromJson(jsonDecode(text) as Map<String, dynamic>);

      expect(back.id, 'x1');
      expect(back.userId, 'u1');
      expect(back.userName, 'Ani');
      expect(back.title, 'Lari Pagi');
      expect(back.type, ActivityType.ride);
      expect(back.description, 'Cerah');
      expect(back.distanceM, 12345.5);
      expect(back.durationS, 3600);
      expect(back.startTime, DateTime(2026, 11, 3, 6, 30));
      expect(back.route, original.route);
      expect(back.kudosBy, <String>['u2', 'u3']);
    });

    test('jumlah komentar tidak ikut disimpan', () {
      expect(original.toJson().containsKey('commentsCount'), isFalse);
      final back = Activity.fromJson(original.toJson());
      expect(back.commentsCount, 0);
    });

    test('copyWith hanya mengubah bagian yang diminta', () {
      final copy = original.copyWith(userName: 'Budi', commentsCount: 2);
      expect(copy.userName, 'Budi');
      expect(copy.commentsCount, 2);
      expect(copy.id, original.id);
      expect(copy.kudosBy, original.kudosBy);
      expect(copy.route, original.route);
    });

    test('kudos dihitung dari daftar pemberi kudos', () {
      expect(original.kudosCount, 2);
      expect(original.isKudosBy('u2'), isTrue);
      expect(original.isKudosBy('u9'), isFalse);
      expect(original.isKudosBy(null), isFalse);
    });
  });
}
