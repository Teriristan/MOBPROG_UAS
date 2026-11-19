import 'dart:math' as math;

import 'package:flutter_lokasi2/data/key_value_store.dart';
import 'package:flutter_lokasi2/data/local_db.dart';
import 'package:flutter_lokasi2/data/seed_data.dart';
import 'package:flutter_lokasi2/models/activity.dart';
import 'package:flutter_lokasi2/models/activity_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;

double _lengthM(List<LatLng> points) {
  const r = 6371000.0;
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.pow(math.sin(dLng / 2), 2);
    total += 2 * r * math.asin(math.sqrt(h));
  }
  return total;
}

void main() {
  // Beberapa jam berbeda, termasuk dini hari, untuk memastikan data contoh
  // tidak pernah berada di masa depan.
  final moments = <DateTime>[
    DateTime(2026, 11, 4, 0, 10),
    DateTime(2026, 11, 4, 12),
    DateTime(2026, 11, 4, 23, 50),
    DateTime(2027, 1, 1, 6),
  ];

  for (final now in moments) {
    group('SeedData pada $now', () {
      final bundle = SeedData.build(now);
      final userIds = bundle.users.map((u) => u.uid).toSet();

      test('ada 5 pengguna contoh dan 26 aktivitas dengan ID unik', () {
        expect(bundle.users.length, 5);
        expect(userIds.length, 5);
        expect(
          userIds.every((id) => id.startsWith(SeedData.userIdPrefix)),
          isTrue,
        );
        expect(bundle.activities.length, 26);
        expect(bundle.activities.map((a) => a.id).toSet().length, 26);
      });

      test('setiap aktivitas milik pengguna contoh dan sudah selesai', () {
        for (final a in bundle.activities) {
          expect(userIds.contains(a.userId), isTrue, reason: a.id);
          expect(a.title, isNotEmpty, reason: a.id);
          expect(a.durationS, greaterThan(0), reason: a.id);
          final end = a.startTime.add(Duration(seconds: a.durationS));
          expect(
            end.isAfter(now),
            isFalse,
            reason: '${a.id} berakhir di masa depan',
          );
        }
      });

      test('ada aktivitas dalam 24 jam terakhir dan dalam 7 hari terakhir', () {
        final day = now.subtract(const Duration(hours: 24));
        final week = now.subtract(const Duration(days: 7));
        expect(
          bundle.activities.where((a) => a.startTime.isAfter(day)).length,
          greaterThanOrEqualTo(2),
        );
        expect(
          bundle.activities.where((a) => a.startTime.isAfter(week)).length,
          greaterThanOrEqualTo(8),
        );
      });

      test('jarak sesuai panjang rute, rute berupa lintasan tertutup', () {
        for (final a in bundle.activities) {
          expect(a.route.length, greaterThanOrEqualTo(40), reason: a.id);
          expect(
            a.route.length,
            lessThanOrEqualTo(LocalDb.maxRoutePoints),
            reason: a.id,
          );
          expect(
            a.distanceM,
            closeTo(_lengthM(a.route), a.distanceM * 0.005),
            reason: a.id,
          );
          expect(
            _lengthM(<LatLng>[a.route.first, a.route.last]),
            lessThan(5),
            reason: a.id,
          );
        }
      });

      test('kecepatan wajar untuk tiap jenis aktivitas', () {
        for (final a in bundle.activities) {
          final mps = a.distanceM / a.durationS;
          switch (a.type) {
            case ActivityType.run:
              expect(mps, inInclusiveRange(2.2, 4.8), reason: a.id);
            case ActivityType.ride:
              expect(mps, inInclusiveRange(4.0, 11.0), reason: a.id);
            case ActivityType.walk:
              expect(mps, inInclusiveRange(0.9, 2.0), reason: a.id);
          }
        }
      });

      test('kudos dan komentar berasal dari pengguna lain', () {
        final byId = <String, Activity>{
          for (final a in bundle.activities) a.id: a,
        };
        for (final a in bundle.activities) {
          expect(a.kudosBy.contains(a.userId), isFalse, reason: a.id);
          expect(a.kudosBy.every(userIds.contains), isTrue, reason: a.id);
        }
        expect(bundle.comments, isNotEmpty);
        bundle.comments.forEach((activityId, list) {
          final activity = byId[activityId];
          expect(activity, isNotNull, reason: activityId);
          for (final c in list) {
            expect(c.userId, isNot(activity!.userId), reason: c.id);
            expect(userIds.contains(c.userId), isTrue, reason: c.id);
            expect(
              c.createdAt.isBefore(activity.startTime),
              isFalse,
              reason: c.id,
            );
            expect(c.createdAt.isAfter(now), isFalse, reason: c.id);
          }
        });
        expect(bundle.activities.any((a) => a.kudosBy.isNotEmpty), isTrue);
      });

      test(
        'relasi mengikuti hanya antar pengguna contoh dan bukan diri sendiri',
        () {
          expect(bundle.follows, isNotEmpty);
          for (final pair in bundle.follows) {
            final parts = pair.split('|');
            expect(parts.length, 2);
            expect(userIds.contains(parts[0]), isTrue);
            expect(userIds.contains(parts[1]), isTrue);
            expect(parts[0], isNot(parts[1]));
          }
        },
      );
    });
  }

  test('hasilnya tetap untuk waktu yang sama', () {
    final now = DateTime(2026, 11, 4, 12);
    final a = SeedData.build(now);
    final b = SeedData.build(now);
    expect(a.activities.map((x) => x.id), b.activities.map((x) => x.id));
    expect(
      a.activities.map((x) => x.distanceM),
      b.activities.map((x) => x.distanceM),
    );
    expect(
      a.activities.map((x) => x.durationS),
      b.activities.map((x) => x.durationS),
    );
    expect(a.activities.first.route, b.activities.first.route);
  });

  test('data contoh bertahan utuh setelah disimpan dan dimuat ulang', () async {
    final now = DateTime(2026, 11, 4, 12);
    final store = MemoryStore();
    final first = LocalDb(now: () => now);
    await first.init(store: store);

    final second = LocalDb(now: () => now);
    await second.init(store: store);

    final before = first.allActivities();
    final after = second.allActivities();
    expect(after.length, before.length);
    for (var i = 0; i < before.length; i++) {
      expect(after[i].id, before[i].id);
      expect(after[i].route, before[i].route);
      expect(after[i].distanceM, before[i].distanceM);
      expect(after[i].startTime, before[i].startTime);
      expect(after[i].kudosBy, before[i].kudosBy);
      expect(after[i].commentsCount, before[i].commentsCount);
    }
  });
}
