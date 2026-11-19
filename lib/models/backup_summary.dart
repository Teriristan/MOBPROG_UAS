/// Ringkasan isi sebuah cadangan data, dipakai untuk meminta konfirmasi
/// sebelum data dipulihkan dan untuk memberi tahu hasilnya.
class BackupSummary {
  const BackupSummary({
    required this.users,
    required this.activities,
    required this.comments,
    required this.follows,
    this.exportedAt,
  });

  /// Jumlah akun.
  final int users;

  /// Jumlah aktivitas.
  final int activities;

  /// Jumlah komentar di semua aktivitas.
  final int comments;

  /// Jumlah hubungan mengikuti.
  final int follows;

  /// Waktu cadangan dibuat (null bila tidak tercatat atau tidak terbaca).
  final DateTime? exportedAt;
}
