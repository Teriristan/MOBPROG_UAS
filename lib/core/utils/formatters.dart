import 'package:intl/intl.dart';

/// Fungsi format tampilan: jarak, durasi, pace, tanggal.
class Fmt {
  Fmt._();

  /// 5230.0 → "5,23"
  static String km(double meters) =>
      NumberFormat('0.00', 'id_ID').format(meters / 1000);

  /// 5230.0 → "5,23 km"
  static String distance(double meters) => '${km(meters)} km';

  /// 3725 → "1:02:05", 725 → "12:05"
  static String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// Pace (menit per km), contoh "5:32". Data belum cukup → "--:--".
  static String pace(double meters, int seconds) {
    if (meters < 10 || seconds <= 0) return '--:--';
    final perKm = (seconds / (meters / 1000)).round();
    final m = perKm ~/ 60;
    final s = perKm % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Kecepatan rata-rata km/jam, contoh "12,4".
  static String speed(double meters, int seconds) {
    if (seconds <= 0) return '0,0';
    final kmh = (meters / 1000) / (seconds / 3600);
    return NumberFormat('0.0', 'id_ID').format(kmh);
  }

  /// "Sen, 3 Nov 2026 • 06:30"
  static String dateTime(DateTime d) =>
      DateFormat('EEE, d MMM y • HH:mm', 'id_ID').format(d);

  /// "3 Nov 2026"
  static String date(DateTime d) => DateFormat('d MMM y', 'id_ID').format(d);

  /// "3 Nov"
  static String shortDate(DateTime d) => DateFormat('d MMM', 'id_ID').format(d);

  /// 900 → "900 B", 2048 → "2,0 KB", 3145728 → "3,0 MB"
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final format = NumberFormat('0.0', 'id_ID');
    if (bytes < 1024 * 1024) return '${format.format(bytes / 1024)} KB';
    return '${format.format(bytes / (1024 * 1024))} MB';
  }
}
