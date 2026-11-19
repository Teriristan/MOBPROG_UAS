/// Pembantu tanggal untuk leaderboard dan statistik.
class Dates {
  Dates._();

  /// Awal hari (00:00) dari tanggal [d].
  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Senin 00:00 pada minggu yang memuat [d].
  static DateTime startOfWeek(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  /// Tanggal 1 pukul 00:00 pada bulan yang memuat [d].
  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
}
