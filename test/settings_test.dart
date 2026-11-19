import 'package:flutter_lokasi2/data/settings_store.dart';
import 'package:flutter_lokasi2/models/activity_type.dart';
import 'package:flutter_lokasi2/models/app_settings.dart';
import 'package:flutter_lokasi2/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Penyimpanan pengaturan yang selalu gagal menulis (penyimpanan penuh/diblokir).
class _FailingStore extends SettingsStore {
  int writes = 0;

  @override
  Future<void> saveWeeklyGoalKm(int km) async {
    writes++;
    throw StateError('penyimpanan penuh');
  }

  @override
  Future<void> saveSimulate(bool value) async {
    writes++;
    throw StateError('penyimpanan penuh');
  }

  @override
  Future<void> saveDefaultType(ActivityType type) async {
    writes++;
    throw StateError('penyimpanan penuh');
  }

  @override
  Future<void> clear() async {
    writes++;
    throw StateError('penyimpanan penuh');
  }
}

/// Penyimpanan yang tidak bisa dibaca sama sekali.
class _UnreadableStore extends SettingsStore {
  @override
  Future<AppSettings> load() async => throw StateError('tidak bisa dibaca');
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  group('AppSettings', () {
    test('nilai bawaan', () {
      const s = AppSettings();

      expect(s.defaultType, ActivityType.run);
      expect(s.simulateByDefault, isFalse);
      expect(s.weeklyGoalKm, 20);
    });

    test('clampGoal menjepit ke 5..200 km', () {
      expect(AppSettings.clampGoal(-10), 5);
      expect(AppSettings.clampGoal(0), 5);
      expect(AppSettings.clampGoal(5), 5);
      expect(AppSettings.clampGoal(37), 37);
      expect(AppSettings.clampGoal(200), 200);
      expect(AppSettings.clampGoal(201), 200);
      expect(AppSettings.clampGoal(100000), 200);
    });

    test('copyWith hanya mengubah bagian yang diminta', () {
      const base = AppSettings(
        defaultType: ActivityType.ride,
        simulateByDefault: true,
        weeklyGoalKm: 50,
      );

      final changed = base.copyWith(simulateByDefault: false);

      expect(changed.defaultType, ActivityType.ride);
      expect(changed.simulateByDefault, isFalse);
      expect(changed.weeklyGoalKm, 50);
      expect(base.simulateByDefault, isTrue);
    });

    test('copyWith ikut menjepit target mingguan', () {
      expect(const AppSettings().copyWith(weeklyGoalKm: 999).weeklyGoalKm, 200);
      expect(const AppSettings().copyWith(weeklyGoalKm: 1).weeklyGoalKm, 5);
    });

    test('kesamaan dinilai dari isinya', () {
      const a = AppSettings(defaultType: ActivityType.walk, weeklyGoalKm: 30);
      const b = AppSettings(defaultType: ActivityType.walk, weeklyGoalKm: 30);

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect(a == a.copyWith(weeklyGoalKm: 35), isFalse);
      expect(a == a.copyWith(defaultType: ActivityType.run), isFalse);
      expect(a == a.copyWith(simulateByDefault: true), isFalse);
    });
  });

  group('SettingsStore', () {
    test('penyimpanan kosong memberi nilai bawaan', () async {
      expect(await SettingsStore().load(), const AppSettings());
    });

    test('menyimpan tiap pengaturan dengan tipe aslinya', () async {
      final store = SettingsStore();

      await store.saveDefaultType(ActivityType.ride);
      await store.saveSimulate(true);
      await store.saveWeeklyGoalKm(35);

      final all = await SharedPreferencesAsync().getAll();
      expect(all, <String, Object?>{
        'lariku_setting_default_type': 'ride',
        'lariku_setting_simulate': true,
        'lariku_setting_weekly_goal_km': 35,
      });
    });

    test('SettingsStore baru membaca apa yang disimpan sebelumnya', () async {
      final first = SettingsStore();
      await first.saveDefaultType(ActivityType.walk);
      await first.saveSimulate(true);
      await first.saveWeeklyGoalKm(75);

      final loaded = await SettingsStore().load();

      expect(loaded.defaultType, ActivityType.walk);
      expect(loaded.simulateByDefault, isTrue);
      expect(loaded.weeklyGoalKm, 75);
    });

    test(
      'target di luar batas dijepit saat disimpan dan saat dibaca',
      () async {
        final store = SettingsStore();
        final prefs = SharedPreferencesAsync();

        await store.saveWeeklyGoalKm(5000);
        expect(await prefs.getInt('lariku_setting_weekly_goal_km'), 200);

        // Nilai yang diubah manual di luar aplikasi juga dijepit.
        await prefs.setInt('lariku_setting_weekly_goal_km', 0);
        expect((await store.load()).weeklyGoalKm, 5);
        await prefs.setInt('lariku_setting_weekly_goal_km', 12345);
        expect((await store.load()).weeklyGoalKm, 200);
      },
    );

    test('jenis aktivitas yang tidak dikenal kembali ke Lari', () async {
      await SharedPreferencesAsync().setString(
        'lariku_setting_default_type',
        'terbang',
      );

      expect((await SettingsStore().load()).defaultType, ActivityType.run);
    });

    test('nilai bertipe salah diabaikan, yang lain tetap terbaca', () async {
      final prefs = SharedPreferencesAsync();
      await prefs.setString('lariku_setting_simulate', 'ya'); // seharusnya bool
      await prefs.setString('lariku_setting_weekly_goal_km', 'banyak'); // int
      await prefs.setInt('lariku_setting_default_type', 7); // seharusnya teks

      final loaded = await SettingsStore().load();

      expect(loaded, const AppSettings());

      await prefs.setString('lariku_setting_default_type', 'ride');
      expect((await SettingsStore().load()).defaultType, ActivityType.ride);
    });

    test('clear hanya menghapus kunci pengaturan', () async {
      final prefs = SharedPreferencesAsync();
      final store = SettingsStore();
      await prefs.setString('lariku_users', '[]');
      await store.saveDefaultType(ActivityType.ride);
      await store.saveSimulate(true);
      await store.saveWeeklyGoalKm(60);

      await store.clear();

      expect(await prefs.getKeys(), <String>{'lariku_users'});
      expect(await store.load(), const AppSettings());
    });
  });

  group('SettingsProvider', () {
    test(
      'load memuat pengaturan tersimpan dan memberi tahu pendengar',
      () async {
        await SettingsStore().saveDefaultType(ActivityType.walk);
        await SettingsStore().saveWeeklyGoalKm(45);
        final provider = SettingsProvider(store: SettingsStore());
        var notified = 0;
        provider.addListener(() => notified++);
        expect(provider.weeklyGoalKm, 20); // belum dimuat

        await provider.load();

        expect(provider.defaultType, ActivityType.walk);
        expect(provider.weeklyGoalKm, 45);
        expect(provider.simulateByDefault, isFalse);
        expect(notified, 1);
      },
    );

    test('load yang gagal mempertahankan nilai sekarang', () async {
      final provider = SettingsProvider(
        store: _UnreadableStore(),
        initial: const AppSettings(weeklyGoalKm: 40),
      );
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.load();

      expect(provider.weeklyGoalKm, 40);
      expect(notified, 1);
    });

    test('setter langsung berlaku, memberi tahu, dan tersimpan', () async {
      final provider = SettingsProvider(store: SettingsStore());
      var notified = 0;
      provider.addListener(() => notified++);

      expect(await provider.setDefaultType(ActivityType.ride), isNull);
      expect(await provider.setSimulateByDefault(true), isNull);
      expect(await provider.setWeeklyGoalKm(35), isNull);

      expect(provider.defaultType, ActivityType.ride);
      expect(provider.simulateByDefault, isTrue);
      expect(provider.weeklyGoalKm, 35);
      expect(notified, 3);

      // Aplikasi dibuka lagi: pengaturan yang sama terbaca.
      final reopened = SettingsProvider(store: SettingsStore());
      await reopened.load();
      expect(reopened.settings, provider.settings);
    });

    test('target mingguan dijepit ke batas', () async {
      final provider = SettingsProvider(store: SettingsStore());

      await provider.setWeeklyGoalKm(9999);
      expect(provider.weeklyGoalKm, 200);
      expect(await SettingsStore().load().then((s) => s.weeklyGoalKm), 200);

      await provider.setWeeklyGoalKm(-3);
      expect(provider.weeklyGoalKm, 5);
    });

    test('nilai yang sama tidak memicu pemberitahuan', () async {
      final provider = SettingsProvider(store: SettingsStore());
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.setDefaultType(ActivityType.run); // sudah Lari
      await provider.setWeeklyGoalKm(20); // sudah 20
      await provider.setSimulateByDefault(false); // sudah mati

      expect(notified, 0);
    });

    test(
      'restoreDefaults mengembalikan semua dan mengosongkan penyimpanan',
      () async {
        final provider = SettingsProvider(store: SettingsStore());
        await provider.setDefaultType(ActivityType.walk);
        await provider.setSimulateByDefault(true);
        await provider.setWeeklyGoalKm(80);

        expect(await provider.restoreDefaults(), isNull);

        expect(provider.settings, const AppSettings());
        expect(await SharedPreferencesAsync().getKeys(), isEmpty);
      },
    );

    test(
      'gagal menyimpan: pesan galat dikembalikan, nilai tetap berlaku',
      () async {
        final store = _FailingStore();
        final provider = SettingsProvider(store: store);

        final message = await provider.setWeeklyGoalKm(55);

        expect(message, contains('tidak dapat disimpan'));
        expect(message, contains('penyimpanan penuh'));
        expect(provider.weeklyGoalKm, 55);
        expect(store.writes, 1);

        expect(await provider.setSimulateByDefault(true), isNotNull);
        expect(await provider.setDefaultType(ActivityType.ride), isNotNull);
        expect(await provider.restoreDefaults(), isNotNull);
        expect(store.writes, 4);
      },
    );

    test('nilai yang sama tetap ditulis ulang ke penyimpanan', () async {
      // Bila penulisan sebelumnya gagal, mengulang nilai yang sama memberi
      // kesempatan kedua agar akhirnya tersimpan.
      final store = _FailingStore();
      final provider = SettingsProvider(store: store);
      await provider.setWeeklyGoalKm(55);

      await provider.setWeeklyGoalKm(55);

      expect(store.writes, 2);
    });
  });
}
