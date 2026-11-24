import 'package:flutter_lokasi2/core/app_exception.dart';
import 'package:flutter_lokasi2/core/utils/gpx_builder.dart';
import 'package:flutter_lokasi2/models/activity.dart';
import 'package:flutter_lokasi2/models/activity_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;

const List<LatLng> _straight = <LatLng>[
  LatLng(-6.200, 106.800),
  LatLng(-6.199, 106.800),
  LatLng(-6.197, 106.800),
];

Activity _activity({
  List<LatLng> route = _straight,
  String title = 'Lari Pagi',
  String description = '',
  ActivityType type = ActivityType.run,
  int durationS = 3000,
}) {
  return Activity(
    id: 'a1',
    userId: 'u1',
    userName: 'Ani',
    title: title,
    type: type,
    description: description,
    distanceM: 333,
    durationS: durationS,
    startTime: DateTime.utc(2026, 11, 3, 6, 30),
    route: route,
  );
}

List<DateTime> _pointTimes(String gpx) {
  final matches = RegExp(
    r'<trkpt[^>]*>\s*<time>([^<]+)</time>',
  ).allMatches(gpx);
  return <DateTime>[for (final m in matches) DateTime.parse(m.group(1)!)];
}

void main() {
  group('GpxBuilder.build', () {
    test('menghasilkan dokumen GPX 1.1 dengan satu trkpt per titik', () {
      final gpx = GpxBuilder.build(_activity());

      expect(gpx.startsWith('<?xml version="1.0" encoding="UTF-8"?>'), isTrue);
      expect(
        gpx,
        contains(
          '<gpx version="1.1" creator="Lariku" '
          'xmlns="http://www.topografix.com/GPX/1/1">',
        ),
      );
      expect(gpx, contains('<name>Lari Pagi</name>'));
      expect(gpx, contains('<type>running</type>'));
      expect(gpx, contains('<time>2026-11-03T06:30:00.000Z</time>'));
      expect('<trkpt'.allMatches(gpx).length, 3);
      expect('</trkpt>'.allMatches(gpx).length, 3);
      expect(gpx.trimRight().endsWith('</gpx>'), isTrue);
    });

    test('koordinat ditulis dengan enam desimal dan titik desimal', () {
      final gpx = GpxBuilder.build(_activity());

      expect(gpx, contains('<trkpt lat="-6.200000" lon="106.800000">'));
      expect(gpx, contains('<trkpt lat="-6.197000" lon="106.800000">'));
    });

    test('jenis aktivitas menjadi tipe trek GPX', () {
      expect(
        GpxBuilder.build(_activity(type: ActivityType.ride)),
        contains('<type>cycling</type>'),
      );
      expect(
        GpxBuilder.build(_activity(type: ActivityType.walk)),
        contains('<type>walking</type>'),
      );
    });

    test('titik pertama = waktu mulai, terakhir = waktu selesai', () {
      final times = _pointTimes(GpxBuilder.build(_activity()));

      expect(times.length, 3);
      expect(times.first, DateTime.utc(2026, 11, 3, 6, 30));
      expect(
        times.last,
        DateTime.utc(2026, 11, 3, 6, 30, 0).add(const Duration(seconds: 3000)),
      );
    });

    test('waktu titik tengah sebanding dengan jarak yang sudah ditempuh', () {
      final times = _pointTimes(GpxBuilder.build(_activity()));
      final start = DateTime.utc(2026, 11, 3, 6, 30);

      // Titik 2 berada 1/3 jarak total dari 3000 detik = 1000 detik.
      final ms = times[1].difference(start).inMilliseconds;
      expect(ms, closeTo(1000000, 5));
    });

    test('waktu selalu naik atau tetap, tidak pernah mundur', () {
      final times = _pointTimes(GpxBuilder.build(_activity()));

      for (var i = 1; i < times.length; i++) {
        expect(times[i].isBefore(times[i - 1]), isFalse);
      }
    });

    test('titik yang sama semua dibagi rata menurut urutan', () {
      const same = LatLng(-6.2, 106.8);
      final times = _pointTimes(
        GpxBuilder.build(
          _activity(route: const <LatLng>[same, same, same], durationS: 100),
        ),
      );
      final start = DateTime.utc(2026, 11, 3, 6, 30);

      expect(times.map((t) => t.difference(start).inSeconds).toList(), <int>[
        0,
        50,
        100,
      ]);
    });

    test('durasi nol membuat semua titik berwaktu sama', () {
      final times = _pointTimes(GpxBuilder.build(_activity(durationS: 0)));

      expect(times.every((t) => t == DateTime.utc(2026, 11, 3, 6, 30)), isTrue);
    });

    test('keterangan hanya ditulis bila ada', () {
      expect(GpxBuilder.build(_activity()), isNot(contains('<desc>')));
      expect(
        GpxBuilder.build(_activity(description: 'Cerah & sejuk')),
        contains('<desc>Cerah &amp; sejuk</desc>'),
      );
    });

    test('karakter khusus XML di judul diganti', () {
      final gpx = GpxBuilder.build(
        _activity(title: 'Lari & <Santai> "pagi" \'ini\''),
      );

      expect(
        gpx,
        contains(
          '<name>Lari &amp; &lt;Santai&gt; &quot;pagi&quot; &apos;ini&apos;'
          '</name>',
        ),
      );
      expect(gpx, isNot(contains('<Santai>')));
    });

    test('karakter kontrol yang dilarang XML dibuang', () {
      final gpx = GpxBuilder.build(_activity(title: 'A\u0000B\u0008C\u001FD'));

      expect(gpx, contains('<name>ABCD</name>'));
    });

    test('rute kurang dari dua titik ditolak', () {
      for (final route in <List<LatLng>>[
        const <LatLng>[],
        const <LatLng>[LatLng(-6.2, 106.8)],
      ]) {
        expect(
          () => GpxBuilder.build(_activity(route: route)),
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'message',
              contains('tidak punya rute'),
            ),
          ),
        );
      }
    });
  });
}
