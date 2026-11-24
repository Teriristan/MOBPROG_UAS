import '../data/local_db.dart';
import '../models/activity.dart';

class ActivityService {
  ActivityService({LocalDb? db}) : _db = db ?? LocalDb.instance;

  final LocalDb _db;

  Future<String> create(Activity activity) => _db.addActivity(activity);

  Stream<List<Activity>> watchFeed({int limit = 30}) {
    return _db.watch<List<Activity>>(
      () => _db.allActivities().take(limit).toList(),
    );
  }

  /// Feed "Mengikuti": aktivitas milik [userIds].
  Stream<List<Activity>> watchFeedOf(Set<String> userIds, {int limit = 50}) {
    return _db.watch<List<Activity>>(
      () => _db
          .allActivities()
          .where((a) => userIds.contains(a.userId))
          .take(limit)
          .toList(),
    );
  }

  /// Semua aktivitas milik satu pengguna, terbaru di atas.
  Stream<List<Activity>> watchByUser(String uid) {
    return _db.watch<List<Activity>>(
      () => _db.allActivities().where((a) => a.userId == uid).toList(),
    );
  }

  /// Satu aktivitas. Bernilai null bila sudah dihapus.
  Stream<Activity?> watchOne(String id) {
    return _db.watch<Activity?>(() => _db.activityById(id));
  }

  /// Menghapus aktivitas beserta semua komentarnya.
  Future<void> delete(String id) => _db.deleteActivity(id);
}
