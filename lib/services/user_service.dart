import 'dart:convert';
import 'dart:typed_data';

import '../data/local_db.dart';
import '../models/app_user.dart';

/// Membaca dan mengubah profil pengguna.
class UserService {
  UserService({LocalDb? db}) : _db = db ?? LocalDb.instance;

  final LocalDb _db;

  Future<AppUser?> getUser(String uid) async => _db.userById(uid);

  /// Profil yang diperbarui otomatis setiap kali datanya berubah.
  Stream<AppUser?> watchUser(String uid) {
    return _db.watch<AppUser?>(() => _db.userById(uid));
  }

  /// Mencari pengguna berdasarkan nama.
  /// Kata kunci kosong menampilkan pengguna yang paling baru mendaftar.
  Future<List<AppUser>> search(String keyword) async {
    return _db.searchUsers(keyword);
  }

  /// Mengubah profil. Nama baru ikut disalin ke aktivitas dan komentar
  /// milik pengguna itu.
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String bio,
  }) {
    return _db.updateProfile(uid: uid, displayName: displayName, bio: bio);
  }

  /// Mengganti foto profil dengan [bytes] (gambar JPEG/PNG).
  Future<void> updatePhoto(String uid, Uint8List bytes) {
    return _db.setUserPhoto(uid, base64Encode(bytes));
  }

  /// Menghapus foto profil (kembali ke avatar huruf).
  Future<void> removePhoto(String uid) => _db.setUserPhoto(uid, null);
}