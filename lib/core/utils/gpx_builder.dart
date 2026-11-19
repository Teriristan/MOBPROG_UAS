import 'dart:math' as math;

import 'package:latlong2/latlong.dart' show LatLng;

import '../../models/activity.dart';
import '../../models/activity_type.dart';
import '../app_exception.dart';

/// Membuat berkas GPX 1.1 dari rute sebuah aktivitas, yang bisa dibuka di
/// Strava, Garmin Connect, Google Earth, dan aplikasi peta lainnya.
class GpxBuilder {
  GpxBuilder._();

  static const String creator = 'Lariku';

  /// Rute disimpan tanpa waktu per titik, jadi waktu tiap titik diperkirakan
  /// dengan membagi durasi aktivitas sebanding dengan jarak yang sudah
  /// ditempuh. Titik pertama = waktu mulai, titik terakhir = waktu selesai.
  static String build(Activity activity) {
    final route = activity.route;
    if (route.length < 2) {
      throw const AppException(
        'Aktivitas ini tidak punya rute GPS, jadi tidak bisa diekspor.',
      );
    }

    final times = _pointTimes(activity);
    final title = escape(activity.title);
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="$creator" '
        'xmlns="http://www.topografix.com/GPX/1/1">',
      )
      ..writeln('  <metadata>')
      ..writeln('    <name>$title</name>')
      ..writeln('    <time>${_utc(activity.startTime)}</time>')
      ..writeln('  </metadata>')
      ..writeln('  <trk>')
      ..writeln('    <name>$title</name>');
    if (activity.description.isNotEmpty) {
      out.writeln('    <desc>${escape(activity.description)}</desc>');
    }
    out
      ..writeln('    <type>${_gpxType(activity.type)}</type>')
      ..writeln('    <trkseg>');
    for (var i = 0; i < route.length; i++) {
      out
        ..writeln(
          '      <trkpt lat="${_coordinate(route[i].latitude)}" '
          'lon="${_coordinate(route[i].longitude)}">',
        )
        ..writeln('        <time>${_utc(times[i])}</time>')
        ..writeln('      </trkpt>');
    }
    out
      ..writeln('    </trkseg>')
      ..writeln('  </trk>')
      ..writeln('</gpx>');
    return out.toString();
  }

  /// Mengganti karakter khusus XML dan membuang karakter kontrol yang tidak
  /// boleh ada di XML 1.0.
  static String escape(String text) {
    return text
        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _gpxType(ActivityType type) => switch (type) {
    ActivityType.run => 'running',
    ActivityType.ride => 'cycling',
    ActivityType.walk => 'walking',
  };

  static String _coordinate(double degrees) => degrees.toStringAsFixed(6);

  static String _utc(DateTime time) => time.toUtc().toIso8601String();

  static List<DateTime> _pointTimes(Activity activity) {
    final route = activity.route;
    final cumulative = List<double>.filled(route.length, 0);
    for (var i = 1; i < route.length; i++) {
      cumulative[i] = cumulative[i - 1] + _distanceM(route[i - 1], route[i]);
    }
    final total = cumulative.last;
    final durationMs = activity.durationS * 1000;

    return <DateTime>[
      for (var i = 0; i < route.length; i++)
        activity.startTime.add(
          Duration(
            milliseconds:
                (durationMs *
                        (total > 0
                            ? cumulative[i] / total
                            : i / (route.length - 1)))
                    .round(),
          ),
        ),
    ];
  }

  /// Jarak dua titik di permukaan bumi (rumus haversine), dalam meter.
  static double _distanceM(LatLng a, LatLng b) {
    const earthRadiusM = 6371000.0;
    double rad(double degrees) => degrees * math.pi / 180;

    final dLat = rad(b.latitude - a.latitude);
    final dLng = rad(b.longitude - a.longitude);
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final h =
        sinLat * sinLat +
        math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * sinLng * sinLng;
    return 2 * earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
  }
}
