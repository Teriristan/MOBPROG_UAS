import 'dart:convert';
import 'dart:typed_data';

import '../data/local_db.dart';
import '../models/app_user.dart';

class UserService {
  UserService({LocalDb? db}) : _db = db ?? LocalDb.instance;

  final LocalDb _db;

  Future<AppUser?> getUser(String uid) async => _db.userById(uid);

  Stream<AppUser?> watchUser(String uid) {
    return _db.watch<AppUser?>(() => _db.userById(uid));
  }

  Future<List<AppUser>> search(String keyword) async {
    return _db.searchUsers(keyword);
  }

  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String bio,
  }) {
    return _db.updateProfile(uid: uid, displayName: displayName, bio: bio);
  }

  Future<void> updatePhoto(String uid, Uint8List bytes) {
    return _db.setUserPhoto(uid, base64Encode(bytes));
  }

  Future<void> removePhoto(String uid) => _db.setUserPhoto(uid, null);
}
