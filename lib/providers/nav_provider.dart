import 'package:flutter/foundation.dart';

/// Tab yang sedang aktif di navigasi bawah.
/// 0 Beranda, 1 Rekam, 2 Statistik, 3 Peringkat, 4 Profil.
class NavProvider extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  void go(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }
}
