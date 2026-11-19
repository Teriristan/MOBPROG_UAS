import 'package:flutter/foundation.dart';

import '../data/settings_store.dart';
import '../models/activity_type.dart';
import '../models/app_settings.dart';

/// Menyimpan [AppSettings] di memori, memberi tahu layar saat berubah, dan
/// menulis perubahannya ke SharedPreferences lewat [SettingsStore].
///
/// Setiap perubahan langsung berlaku di layar. Fungsi pengubah mengembalikan
/// pesan kesalahan bila perubahan tidak bisa disimpan (null berarti berhasil).
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

  /// Membaca pengaturan dari penyimpanan. Bila gagal dibaca, nilai yang
  /// sekarang dipertahankan supaya aplikasi tetap bisa dibuka.
  Future<void> load() async {
    try {
      _settings = await _store.load();
    } catch (_) {
      // Pakai nilai bawaan.
    }
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

  /// Target mingguan dijepit ke rentang yang diizinkan oleh [AppSettings].
  Future<String?> setWeeklyGoalKm(int km) {
    final next = _settings.copyWith(weeklyGoalKm: km);
    return _change(next, () => _store.saveWeeklyGoalKm(next.weeklyGoalKm));
  }

  /// Mengembalikan semua pengaturan ke nilai bawaan.
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
