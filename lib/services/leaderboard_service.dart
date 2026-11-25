import '../data/local_db.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';

class LeaderboardEntry {
  LeaderboardEntry({required this.userId, required this.userName});

  final String userId;
  final String userName;
  double distanceM = 0;
  int durationS = 0;
  int count = 0;
}

class LeaderboardService {
  LeaderboardService({LocalDb? db}) : _db = db ?? LocalDb.instance;

  final LocalDb _db;
  Stream<List<Activity>> watchSince(DateTime since) {
    return _db.watch<List<Activity>>(
      () => _db
          .allActivities()
          .where((a) => !a.startTime.isBefore(since))
          .toList(),
    );
  }

  static List<LeaderboardEntry> rank(
    List<Activity> activities, {
    ActivityType? type,
    Set<String>? onlyUsers,
  }) {
    final byUser = <String, LeaderboardEntry>{};

    for (final a in activities) {
      if (type != null && a.type != type) continue;
      if (onlyUsers != null && !onlyUsers.contains(a.userId)) continue;

      final entry = byUser.putIfAbsent(
        a.userId,
        () => LeaderboardEntry(userId: a.userId, userName: a.userName),
      );
      entry.distanceM += a.distanceM;
      entry.durationS += a.durationS;
      entry.count += 1;
    }

    final list = byUser.values.toList()
      ..sort((a, b) => b.distanceM.compareTo(a.distanceM));
    return list;
  }
}
