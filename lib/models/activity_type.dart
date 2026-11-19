/// Jenis aktivitas: lari, sepeda, jalan.
///
/// Enum ini sengaja bebas dari Flutter supaya lapisan data bisa diuji tanpa
/// tampilan. Ikon dan warnanya ada di `ActivityTypeStyle`
/// (lib/core/theme/bootstrap_theme.dart).
enum ActivityType {
  run('Lari', 3.0),
  ride('Sepeda', 7.0),
  walk('Jalan', 1.4);

  const ActivityType(this.label, this.simulatedSpeedMps);

  final String label;

  /// Kecepatan (meter per detik) yang dipakai mode simulasi dan data contoh.
  final double simulatedSpeedMps;

  /// Sepeda ditampilkan dalam km/jam, lainnya dalam pace (menit per km).
  bool get usesSpeed => this == ActivityType.ride;

  /// Mengubah teks yang tersimpan (`run`, `ride`, `walk`) menjadi enum.
  static ActivityType fromKey(String? key) {
    for (final t in ActivityType.values) {
      if (t.name == key) return t;
    }
    return ActivityType.run;
  }
}
