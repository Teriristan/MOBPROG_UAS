import 'dart:math' as math;

import 'package:latlong2/latlong.dart' show LatLng;

import '../core/utils/route_utils.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';
import '../models/app_user.dart';
import '../models/comment.dart';

/// Kumpulan data contoh yang dimuat saat aplikasi pertama kali dibuka,
/// supaya feed, peringkat, dan pencarian teman tidak kosong.
class SeedBundle {
  const SeedBundle({
    required this.users,
    required this.activities,
    required this.comments,
    required this.follows,
  });

  final List<AppUser> users;
  final List<Activity> activities;

  /// Kunci: ID aktivitas.
  final Map<String, List<Comment>> comments;

  /// Pasangan "pengikut|diikuti".
  final Set<String> follows;
}

/// Pembuat data contoh. Hasilnya tetap (tidak acak) untuk waktu [build]
/// yang sama, sehingga mudah diuji.
///
/// Pengguna contoh tidak punya kata sandi, jadi tidak bisa dipakai masuk.
/// Mereka hanya ada sebagai teman olahraga yang bisa diikuti.
class SeedData {
  SeedData._();

  /// Naikkan angka ini bila isi data contoh berubah.
  static const int version = 1;

  /// Awalan ID pengguna contoh.
  static const String userIdPrefix = 'demo_';

  static SeedBundle build(DateTime now) {
    final rnd = math.Random(2026);

    final users = <AppUser>[
      for (final p in _people)
        AppUser(
          uid: p.uid,
          displayName: p.name,
          bio: p.bio,
          createdAt: now.subtract(Duration(days: p.joinedDaysAgo)),
        ),
    ];

    final activities = <Activity>[];
    final comments = <String, List<Comment>>{};

    for (var i = 0; i < _slots.length; i++) {
      final slot = _slots[i];
      final person = _people[slot.person];
      final place = _places[slot.place];
      final id = 'seed_a${(i + 1).toString().padLeft(2, '0')}';

      final route = _buildRoute(rnd, place, slot.km * 1000, slot.type);
      final distanceM = (_length(route) * 10).round() / 10;

      final noise = 0.94 + rnd.nextDouble() * 0.12;
      final speed = slot.type.simulatedSpeedMps * person.ability * noise;
      final durationS = (distanceM / speed).round();

      final DateTime start;
      if (slot.daysAgo == 0) {
        // Aktivitas hari ini: selesai beberapa menit sebelum sekarang.
        start = now.subtract(
          Duration(seconds: durationS, minutes: slot.minutesSinceEnd),
        );
      } else {
        final day = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: slot.daysAgo));
        start = day.add(Duration(hours: slot.hour, minutes: slot.minute));
      }
      final end = start.add(Duration(seconds: durationS));

      final kudosBy = <String>[
        for (final other in _people)
          if (other.uid != person.uid && rnd.nextDouble() < 0.55) other.uid,
      ];

      activities.add(
        Activity(
          id: id,
          userId: person.uid,
          userName: person.name,
          title: slot.title,
          type: slot.type,
          description: slot.description,
          distanceM: distanceM,
          durationS: durationS,
          startTime: start,
          route: route,
          kudosBy: kudosBy,
        ),
      );

      if (rnd.nextDouble() < 0.5) {
        final list = <Comment>[];
        final count = 1 + rnd.nextInt(2);
        var at = end;
        for (var c = 0; c < count; c++) {
          var author = _people[rnd.nextInt(_people.length)];
          if (author.uid == person.uid) {
            author = _people[(slot.person + 1 + c) % _people.length];
          }
          at = at.add(Duration(minutes: 15 + rnd.nextInt(200)));
          final limit = now.subtract(const Duration(minutes: 1));
          final when = at.isAfter(limit) ? limit : at;
          list.add(
            Comment(
              id: 'seed_c${(i + 1).toString().padLeft(2, '0')}_${c + 1}',
              userId: author.uid,
              userName: author.name,
              text: _phrases[rnd.nextInt(_phrases.length)],
              createdAt: when,
            ),
          );
        }
        comments[id] = list;
      }
    }

    return SeedBundle(
      users: users,
      activities: activities,
      comments: comments,
      follows: <String>{
        for (final pair in _followPairs)
          '${_people[pair.$1].uid}|${_people[pair.$2].uid}',
      },
    );
  }

  // ---------------------------------------------------------------------
  // Pembuat rute

  /// Membuat rute berbentuk lintasan tertutup di sekitar [place] dengan
  /// panjang mendekati [targetM] meter, lalu membulatkannya seperti saat
  /// disimpan (supaya sama persis sebelum dan sesudah dimuat ulang).
  static List<LatLng> _buildRoute(
    math.Random rnd,
    _Place place,
    double targetM,
    ActivityType type,
  ) {
    final aspect = switch (type) {
      ActivityType.ride => 1.5 + rnd.nextDouble() * 0.9,
      ActivityType.run => 1.0 + rnd.nextDouble() * 0.5,
      ActivityType.walk => 1.0 + rnd.nextDouble() * 0.3,
    };
    final rotation = rnd.nextDouble() * math.pi;
    final wobble1 = 0.08 + rnd.nextDouble() * 0.10;
    final wobble2 = 0.03 + rnd.nextDouble() * 0.06;
    final phase1 = rnd.nextDouble() * 2 * math.pi;
    final phase2 = rnd.nextDouble() * 2 * math.pi;
    final n = math.min(140, math.max(48, (targetM / 40).round()));

    final metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * math.cos(place.lat * math.pi / 180);

    List<LatLng> make(double scale, double jitterM) {
      final xs = <double>[];
      final ys = <double>[];
      for (var i = 0; i <= n; i++) {
        final t = 2 * math.pi * i / n;
        final w =
            1 +
            wobble1 * math.sin(3 * t + phase1) +
            wobble2 * math.sin(5 * t + phase2);
        final x0 = scale * aspect * math.cos(t) * w;
        final y0 = scale * math.sin(t) * w;
        xs.add(x0 * math.cos(rotation) - y0 * math.sin(rotation));
        ys.add(x0 * math.sin(rotation) + y0 * math.cos(rotation));
      }

      final points = <LatLng>[];
      for (var i = 0; i <= n; i++) {
        var dx = xs[i] - xs[0];
        var dy = ys[i] - ys[0];
        final isEnd = i == 0 || i == n;
        if (!isEnd && jitterM > 0) {
          dx += (rnd.nextDouble() - 0.5) * 2 * jitterM;
          dy += (rnd.nextDouble() - 0.5) * 2 * jitterM;
        }
        points.add(
          LatLng(
            place.lat + dy / metersPerDegLat,
            place.lng + dx / metersPerDegLng,
          ),
        );
      }
      return points;
    }

    // Bentuk dasar berukuran 1 km dipakai untuk menentukan skala.
    final unit = make(1000, 0);
    final scale = 1000 * targetM / _length(unit);
    final raw = make(scale, 1.5);
    return RouteUtils.decode(RouteUtils.encode(raw));
  }

  /// Panjang rute dalam meter (rumus haversine).
  static double _length(List<LatLng> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _haversine(points[i - 1], points[i]);
    }
    return total;
  }

  static double _haversine(LatLng a, LatLng b) {
    const earthRadiusM = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final h =
        sinLat * sinLat +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            sinLng *
            sinLng;
    return 2 * earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
  }

  // ---------------------------------------------------------------------
  // Data

  static const List<_Person> _people = <_Person>[
    _Person(
      uid: 'demo_rina',
      name: 'Rina Pratama',
      bio: 'Pelari pagi. Target tahun ini: half marathon.',
      ability: 1.05,
      joinedDaysAgo: 40,
    ),
    _Person(
      uid: 'demo_budi',
      name: 'Budi Santoso',
      bio: 'Gowes tiap akhir pekan keliling Jakarta.',
      ability: 1.0,
      joinedDaysAgo: 35,
    ),
    _Person(
      uid: 'demo_sari',
      name: 'Sari Wulandari',
      bio: 'Jalan santai dan lari ringan sebelum kerja.',
      ability: 0.9,
      joinedDaysAgo: 30,
    ),
    _Person(
      uid: 'demo_andi',
      name: 'Andi Wijaya',
      bio: 'Suka rute baru. Ayo lari bareng!',
      ability: 1.1,
      joinedDaysAgo: 25,
    ),
    _Person(
      uid: 'demo_dewi',
      name: 'Dewi Lestari',
      bio: 'Pelan tapi konsisten.',
      ability: 0.85,
      joinedDaysAgo: 18,
    ),
  ];

  static const List<_Place> _places = <_Place>[
    _Place(-6.2185, 106.8020), // 0 GBK Senayan
    _Place(-6.1754, 106.8272), // 1 Monas
    _Place(-6.1966, 106.8319), // 2 Taman Menteng
    _Place(-6.1250, 106.8440), // 3 Ancol
    _Place(-6.1352, 106.8133), // 4 Kota Tua
    _Place(-6.2608, 106.8135), // 5 Kemang
    _Place(-6.1450, 106.8650), // 6 Danau Sunter
    _Place(-6.3025, 106.8951), // 7 Taman Mini
  ];

  static const List<_Slot> _slots = <_Slot>[
    // Hari ini (selesai beberapa menit sebelum sekarang).
    _Slot(
      0,
      0,
      0,
      0,
      ActivityType.run,
      5.2,
      0,
      'Lari Pagi di GBK',
      'Udara masih sejuk, pace terasa enak.',
      minutesSinceEnd: 40,
    ),
    _Slot(
      1,
      0,
      0,
      0,
      ActivityType.ride,
      24.5,
      1,
      'Gowes Keliling Monas',
      '',
      minutesSinceEnd: 90,
    ),
    _Slot(
      3,
      0,
      0,
      0,
      ActivityType.run,
      8.1,
      2,
      'Lari Sore Menteng',
      'Coba rute baru lewat taman.',
      minutesSinceEnd: 20,
    ),
    // Kemarin dan seterusnya.
    _Slot(2, 1, 6, 30, ActivityType.walk, 3.4, 2, 'Jalan Pagi Santai', ''),
    _Slot(
      4,
      1,
      17,
      10,
      ActivityType.walk,
      2.6,
      6,
      'Jalan Sore Danau Sunter',
      'Santai sambil menunggu matahari terbenam.',
    ),
    _Slot(0, 1, 5, 45, ActivityType.run, 6.8, 1, 'Lari Pagi Monas', ''),
    _Slot(
      1,
      2,
      6,
      0,
      ActivityType.ride,
      31.2,
      3,
      'Gowes Ancol',
      'Angin lumayan kencang di pinggir pantai.',
    ),
    _Slot(3, 2, 17, 30, ActivityType.run, 5.0, 5, 'Lari Sore Kemang', ''),
    _Slot(
      2,
      3,
      6,
      15,
      ActivityType.run,
      4.2,
      0,
      'Lari Ringan',
      'Mulai lagi setelah libur seminggu.',
    ),
    _Slot(
      0,
      3,
      17,
      40,
      ActivityType.run,
      10.3,
      0,
      'Long Run GBK',
      'Latihan persiapan half marathon.',
    ),
    _Slot(4, 4, 6, 40, ActivityType.walk, 3.1, 1, 'Jalan Pagi', ''),
    _Slot(1, 4, 16, 50, ActivityType.ride, 18.7, 4, 'Gowes Kota Tua', ''),
    _Slot(
      3,
      5,
      5,
      50,
      ActivityType.run,
      12.4,
      7,
      'Lari Jauh Taman Mini',
      'Rute terpanjang bulan ini.',
    ),
    _Slot(2, 6, 17, 20, ActivityType.walk, 4.5, 2, 'Jalan Sore Menteng', ''),
    _Slot(0, 7, 5, 30, ActivityType.run, 5.5, 1, 'Lari Pagi', ''),
    _Slot(
      1,
      8,
      6,
      20,
      ActivityType.ride,
      42.0,
      7,
      'Gowes Akhir Pekan',
      'Sampai Taman Mini dan kembali.',
    ),
    _Slot(
      4,
      9,
      17,
      0,
      ActivityType.run,
      3.6,
      6,
      'Lari Pertama Setelah Lama',
      'Pelan-pelan saja dulu.',
    ),
    _Slot(3, 10, 6, 10, ActivityType.ride, 22.8, 5, 'Gowes Kemang', ''),
    _Slot(2, 12, 6, 35, ActivityType.run, 5.7, 3, 'Lari Pagi Ancol', ''),
    _Slot(0, 14, 5, 40, ActivityType.run, 7.4, 2, 'Lari Pagi Menteng', ''),
    _Slot(1, 15, 16, 30, ActivityType.ride, 27.0, 0, 'Sepeda Sore GBK', ''),
    _Slot(4, 17, 6, 45, ActivityType.walk, 2.2, 4, 'Jalan Pagi Kota Tua', ''),
    _Slot(3, 19, 17, 15, ActivityType.run, 9.6, 1, 'Lari Sore Monas', ''),
    _Slot(2, 21, 6, 25, ActivityType.walk, 3.8, 0, 'Jalan Pagi GBK', ''),
    _Slot(
      0,
      24,
      5,
      55,
      ActivityType.run,
      21.1,
      0,
      'Latihan Half Marathon',
      'Jarak penuh pertama. Kaki pegal tapi senang.',
    ),
    _Slot(1, 27, 6, 5, ActivityType.ride, 35.5, 3, 'Gowes Ancol Jauh', ''),
  ];

  static const List<String> _phrases = <String>[
    'Mantap, lanjutkan!',
    'Keren banget pace-nya.',
    'Semangat terus ya.',
    'Rutenya enak, besok aku ikut.',
    'Konsisten banget, salut.',
    'Wah, jauh juga. Mantap!',
    'Cuaca lagi enak buat lari.',
    'Kapan-kapan lari bareng yuk.',
  ];

  /// (pengikut, diikuti) berdasarkan urutan di [_people].
  static const List<(int, int)> _followPairs = <(int, int)>[
    (0, 1),
    (0, 2),
    (1, 0),
    (2, 0),
    (3, 0),
    (3, 1),
    (4, 2),
    (4, 0),
  ];
}

class _Person {
  const _Person({
    required this.uid,
    required this.name,
    required this.bio,
    required this.ability,
    required this.joinedDaysAgo,
  });

  final String uid;
  final String name;
  final String bio;

  /// Pengali kecepatan: makin besar makin cepat.
  final double ability;
  final int joinedDaysAgo;
}

class _Place {
  const _Place(this.lat, this.lng);

  final double lat;
  final double lng;
}

class _Slot {
  const _Slot(
    this.person,
    this.daysAgo,
    this.hour,
    this.minute,
    this.type,
    this.km,
    this.place,
    this.title,
    this.description, {
    this.minutesSinceEnd = 0,
  });

  /// Indeks di daftar pengguna contoh.
  final int person;

  /// 0 = hari ini (jam dihitung mundur dari sekarang).
  final int daysAgo;
  final int hour;
  final int minute;
  final ActivityType type;
  final double km;

  /// Indeks di daftar tempat.
  final int place;
  final String title;
  final String description;

  /// Hanya untuk aktivitas hari ini: selisih menit antara selesai dan sekarang.
  final int minutesSinceEnd;
}
