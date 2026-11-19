import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/follow_service.dart';

/// Menyimpan daftar UID yang diikuti pengguna yang sedang login,
/// dipakai oleh feed, pencarian teman, profil, dan leaderboard.
class FollowProvider extends ChangeNotifier {
  FollowProvider({FollowService? service})
    : _service = service ?? FollowService();

  final FollowService _service;

  StreamSubscription<Set<String>>? _sub;
  String? _uid;
  Set<String> _following = <String>{};

  Set<String> get followingIds => _following;

  bool isFollowing(String uid) => _following.contains(uid);

  /// Dipanggil setiap status login berubah (lewat ProxyProvider).
  void updateUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _sub = null;
    _following = <String>{};

    if (uid != null) {
      _sub = _service.watchFollowingIds(uid).listen((ids) {
        _following = ids;
        notifyListeners();
      }, onError: (Object e) => debugPrint('watchFollowingIds gagal: $e'));
    }
  }

  /// Mengikuti atau berhenti mengikuti [target].
  Future<void> toggle(String target) async {
    final me = _uid;
    if (me == null || me == target) return;
    if (isFollowing(target)) {
      await _service.unfollow(me, target);
    } else {
      await _service.follow(me, target);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
