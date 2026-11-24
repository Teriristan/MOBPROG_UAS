import '../data/local_db.dart';

class FollowService {
  FollowService({LocalDb? db}) : _db = db ?? LocalDb.instance;

  final LocalDb _db;

  Future<void> follow(String me, String target) {
    return _db.setFollow(me: me, target: target, follow: true);
  }

  Future<void> unfollow(String me, String target) {
    return _db.setFollow(me: me, target: target, follow: false);
  }

  /// Daftar UID yang diikuti oleh [uid].
  Stream<Set<String>> watchFollowingIds(String uid) {
    return _db.watch<Set<String>>(() => _db.followingOf(uid));
  }

  Stream<Set<String>> watchFollowerIds(String uid) {
    return _db.watch<Set<String>>(() => _db.followersOf(uid));
  }

  Stream<int> watchFollowersCount(String uid) {
    return _db.watch<int>(() => _db.followersCount(uid));
  }

  Stream<int> watchFollowingCount(String uid) {
    return _db.watch<int>(() => _db.followingCount(uid));
  }
}
