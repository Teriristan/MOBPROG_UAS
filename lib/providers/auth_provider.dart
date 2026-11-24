import 'package:flutter/foundation.dart';
import '../models/session_user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _auth = authService ?? AuthService() {
    _user = _auth.currentUser;
  }

  final AuthService _auth;
  SessionUser? _user;

  SessionUser? get user => _user;
  bool get isLoggedIn => _user != null;

  String get displayName {
    final u = _user;
    if (u == null) return 'Pengguna';
    final name = u.displayName.trim();
    if (name.isNotEmpty) return name;
    return u.email.split('@').first;
  }

  String get email => _user?.email ?? '';

  Future<void> login(String email, String password) async {
    _user = await _auth.login(email: email, password: password);
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    _user = await _auth.register(name: name, email: email, password: password);
    notifyListeners();
  }

  Future<void> updateDisplayName(String name) async {
    await _auth.updateDisplayName(name);
    _user = _auth.currentUser;
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> resetLocalData() async {
    try {
      await _auth.resetLocalData();
    } finally {
      syncSession();
    }
  }

  void syncSession() {
    _user = _auth.currentUser;
    notifyListeners();
  }
}
