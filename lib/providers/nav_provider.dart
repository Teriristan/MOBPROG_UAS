import 'package:flutter/foundation.dart';

class NavProvider extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  void go(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }
}
