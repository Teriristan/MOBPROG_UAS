import '../core/app_exception.dart';
import '../data/local_db.dart';
import '../models/session_user.dart';

/// Akun dan sesi login. Semua disimpan di database lokal (localStorage),
/// tanpa server.
class AuthService {
  AuthService({LocalDb? db}) : _db = db ?? LocalDb.instance;

  final LocalDb _db;

  /// Akun yang sedang masuk, atau null.
  SessionUser? get currentUser => _db.currentUser;

  /// Membuat akun baru lalu langsung masuk.
  Future<SessionUser> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _db.register(name: name, email: email, password: password);
  }

  Future<SessionUser> login({required String email, required String password}) {
    return _db.login(email: email, password: password);
  }

  Future<void> logout() => _db.logout();

  /// Mengubah nama tampilan akun yang sedang masuk.
  Future<void> updateDisplayName(String name) => _db.updateDisplayName(name);

  /// Menghapus semua data lokal dan memuat ulang data contoh.
  Future<void> resetLocalData() => _db.resetAll();

  static bool isValidEmail(String value) => LocalDb.isValidEmail(value);

  /// Mengubah error menjadi pesan Bahasa Indonesia yang siap ditampilkan.
  static String messageFor(Object error) {
    if (error is AppException) return error.message;
    return 'Terjadi kesalahan: $error';
  }
}
