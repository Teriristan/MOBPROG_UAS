// Rentang waktu yang bisa dipilih di halaman statistik.
enum StatsPeriod {
  week('Minggu ini', 'Total minggu ini'),
  month('Bulan ini', 'Total bulan ini'),
  all('Semua', 'Total keseluruhan');
  const StatsPeriod(this.label, this.totalTitle);
  final String label;
  final String totalTitle;
}