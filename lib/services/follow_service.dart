import '../data/local_db.dart';

/// Relasi mengikuti antar pengguna.
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

  /// Jumlah pengikut [uid].
  Stream<int> watchFollowersCount(String uid) {
    return _db.watch<int>(() => _db.followersCount(uid));
  }

  /// Jumlah orang yang diikuti [uid].
  Stream<int> watchFollowingCount(String uid) {
    return _db.watch<int>(() => _db.followingCount(uid));
  }
}
