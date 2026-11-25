import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_type.dart';
import '../models/app_settings.dart';

class SettingsStore {
  SettingsStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const String keyDefaultType = 'lariku_setting_default_type';
  static const String keySimulate = 'lariku_setting_simulate';
  static const String keyWeeklyGoalKm = 'lariku_setting_weekly_goal_km';

  Future<AppSettings> load() async {
    const defaults = AppSettings();

    final type = await _tryRead<String>(() => _prefs.getString(keyDefaultType));
    final simulate = await _tryRead<bool>(() => _prefs.getBool(keySimulate));
    final goal = await _tryRead<int>(() => _prefs.getInt(keyWeeklyGoalKm));

    return AppSettings(
      defaultType: type == null
          ? defaults.defaultType
          : ActivityType.fromKey(type),
      simulateByDefault: simulate ?? defaults.simulateByDefault,
      weeklyGoalKm: goal == null
          ? defaults.weeklyGoalKm
          : AppSettings.clampGoal(goal),
    );
  }

  Future<void> saveDefaultType(ActivityType type) =>
      _prefs.setString(keyDefaultType, type.name);

  Future<void> saveSimulate(bool value) => _prefs.setBool(keySimulate, value);

  Future<void> saveWeeklyGoalKm(int km) =>
      _prefs.setInt(keyWeeklyGoalKm, AppSettings.clampGoal(km));

  Future<void> clear() async {
    await _prefs.remove(keyDefaultType);
    await _prefs.remove(keySimulate);
    await _prefs.remove(keyWeeklyGoalKm);
  }

  static Future<T?> _tryRead<T>(Future<T?> Function() read) async {
    try {
      return await read();
    } catch (_) {
      return null;
    }
  }
}
