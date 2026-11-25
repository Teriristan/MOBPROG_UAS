class BackupSummary {
  const BackupSummary({
    required this.users,
    required this.activities,
    required this.comments,
    required this.follows,
    this.exportedAt,
  });

  final int users;
  final int activities;
  final int comments;
  final int follows;
  final DateTime? exportedAt;
}
