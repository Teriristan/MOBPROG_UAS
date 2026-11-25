import 'package:flutter/foundation.dart';

import '../data/settings_store.dart';
import '../models/activity_type.dart';
import '../models/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    SettingsStore? store,
    AppSettings initial = const AppSettings(),
  }) : _store = store ?? SettingsStore(),
       _settings = initial;

  final SettingsStore _store;
  AppSettings _settings;

  AppSettings get settings => _settings;
  ActivityType get defaultType => _settings.defaultType;
  bool get simulateByDefault => _settings.simulateByDefault;
  int get weeklyGoalKm => _settings.weeklyGoalKm;

  Future<void> load() async {
    try {
      _settings = await _store.load();
    } catch (_) {}
    notifyListeners();
  }

  Future<String?> setDefaultType(ActivityType type) {
    return _change(
      _settings.copyWith(defaultType: type),
      () => _store.saveDefaultType(type),
    );
  }

  Future<String?> setSimulateByDefault(bool value) {
    return _change(
      _settings.copyWith(simulateByDefault: value),
      () => _store.saveSimulate(value),
    );
  }

  Future<String?> setWeeklyGoalKm(int km) {
    final next = _settings.copyWith(weeklyGoalKm: km);
    return _change(next, () => _store.saveWeeklyGoalKm(next.weeklyGoalKm));
  }

  Future<String?> restoreDefaults() {
    return _change(const AppSettings(), _store.clear);
  }

  Future<String?> _change(
    AppSettings next,
    Future<void> Function() persist,
  ) async {
    if (next != _settings) {
      _settings = next;
      notifyListeners();
    }
    try {
      await persist();
      return null;
    } catch (e) {
      return 'Pengaturan berlaku untuk sementara, tetapi tidak dapat '
          'disimpan di perangkat ($e).';
    }
  }
}
