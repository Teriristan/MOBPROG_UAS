import 'dart:math';

import 'package:flutter_lokasi2/data/local_db.dart';
import 'package:flutter_lokasi2/data/prefs_store.dart';
import 'package:flutter_lokasi2/models/activity.dart';
import 'package:flutter_lokasi2/models/activity_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final DateTime _now = DateTime(2026, 11, 4, 12);

/// Membuka database di atas PrefsStore, seperti aplikasi yang baru dijalankan.
Future<LocalDb> _launch({bool seed = false}) async {
  final db = LocalDb(now: () => _now, random: Random(1));
  await db.init(store: PrefsStore(), seed: seed);
  return db;
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  group('PrefsStore', () {
    test('kunci yang belum ada terbaca null', () async {
      expect(await PrefsStore().read('lariku_users'), isNull);
    });

    test('menulis, menimpa, lalu menghapus nilai', () async {
      final store = PrefsStore();

      await store.write('k', 'satu');
      expect(await store.read('k'), 'satu');

      await store.write('k', 'dua');
      expect(await store.read('k'), 'dua');

      await store.remove('k');
      expect(await store.read('k'), isNull);
    });

    test('teks disimpan apa adanya dengan kunci yang sama', () async {
      const json = '[{"a":1}]';
      await PrefsStore().write('lariku_users', json);

      final all = await SharedPreferencesAsync().getAll();
      expect(all, <String, Object?>{'lariku_users': json});
    });

    test('PrefsStore baru membaca data dari PrefsStore sebelumnya', () async {
      await PrefsStore().write('lariku_session', 'u1');
      expect(await PrefsStore().read('lariku_session'), 'u1');
    });

    test('tanpa platform penyimpanan, PrefsStore() melempar StateError', () {
      SharedPreferencesAsyncPlatform.instance = null;
      expect(PrefsStore.new, throwsA(isA<StateError>()));
    });
  });

  group('LocalDb di atas PrefsStore', () {
    test('akun, aktivitas, kudos, komentar, dan pengikut bertahan', () async {
      final db = await _launch(seed: true);
      final me = await db.register(
        name: 'Ani',
        email: 'ani@mail.com',
        password: 'rahasia1',
      );
      final friend = db.searchUsers('').firstWhere((u) => u.uid != me.uid).uid;

      final id = await db.addActivity(
        Activity(
          id: '',
          userId: me.uid,
          userName: 'Ani',
          title: 'Lari Sore',
          type: ActivityType.run,
          distanceM: 5000,
          durationS: 1500,
          startTime: _now.subtract(const Duration(hours: 2)),
          route: const <LatLng>[LatLng(-6.2, 106.8), LatLng(-6.21, 106.81)],
        ),
      );
      await db.setKudos(activityId: id, uid: friend, give: true);
      await db.addComment(
        activityId: id,
        userId: me.uid,
        userName: 'Ani',
        text: 'Semangat!',
      );
      await db.setFollow(me: me.uid, target: friend, follow: true);

      // Aplikasi ditutup lalu dibuka lagi: objek baru, penyimpanan yang sama.
      final again = await _launch(seed: true);

      expect(again.currentUser?.uid, me.uid);
      final saved = again.activityById(id)!;
      expect(saved.title, 'Lari Sore');
      expect(saved.kudosBy, <String>[friend]);
      expect(saved.commentsCount, 1);
      expect(saved.route.length, 2);
      expect(again.commentsFor(id).single.text, 'Semangat!');
      expect(again.followingOf(me.uid), <String>{friend});

      // Data contoh tidak dimuat ulang menimpa data pengguna.
      expect(again.searchUsers('ani').length, 1);
    });

    test(
      'hanya kunci berawalan lariku_ yang ditulis; sesi hilang saat keluar',
      () async {
        final db = await _launch();
        await db.register(
          name: 'Ani',
          email: 'ani@mail.com',
          password: 'rahasia1',
        );

        final prefs = SharedPreferencesAsync();
        var keys = await prefs.getKeys();
        expect(keys, contains('lariku_session'));
        expect(keys.every((k) => k.startsWith(LocalDb.keyPrefix)), isTrue);

        await db.logout();
        keys = await prefs.getKeys();
        expect(keys.contains('lariku_session'), isFalse);
        expect(keys, contains('lariku_users'));
      },
    );

    test('atur ulang menghapus akun dan memuat kembali data contoh', () async {
      final db = await _launch(seed: true);
      await db.register(
        name: 'Ani',
        email: 'ani@mail.com',
        password: 'rahasia1',
      );

      await db.resetAll();
      final again = await _launch(seed: true);

      expect(again.currentUser, isNull);
      expect(again.searchUsers('ani'), isEmpty);
      expect(again.searchUsers('').length, 5);
      expect(again.allActivities(), isNotEmpty);
    });
  });
}
