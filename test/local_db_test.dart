import 'dart:convert';
import 'dart:math';

import 'package:flutter_lokasi2/core/app_exception.dart';
import 'package:flutter_lokasi2/data/key_value_store.dart';
import 'package:flutter_lokasi2/data/local_db.dart';
import 'package:flutter_lokasi2/models/activity.dart';
import 'package:flutter_lokasi2/models/activity_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;

class _FlakyStore extends MemoryStore {
  bool failWrites = false;

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('penyimpanan penuh');
    await super.write(key, value);
  }
}

final DateTime _now = DateTime(2026, 11, 4, 12);

Future<LocalDb> _open({
  KeyValueStore? store,
  bool seed = false,
  DateTime Function()? clock,
}) async {
  final db = LocalDb(now: clock ?? () => _now, random: Random(1));
  await db.init(store: store ?? MemoryStore(), seed: seed);
  return db;
}

Future<String> _registerAni(LocalDb db) async {
  final me = await db.register(
    name: 'Ani',
    email: 'ani@mail.com',
    password: 'rahasia1',
  );
  return me.uid;
}

Activity _draft(
  String userId, {
  String title = 'Lari Pagi',
  int hoursAgo = 3,
  List<LatLng> route = const <LatLng>[],
}) {
  return Activity(
    id: '',
    userId: userId,
    userName: 'Ani',
    title: title,
    type: ActivityType.run,
    distanceM: 5000,
    durationS: 1500,
    startTime: _now.subtract(Duration(hours: hoursAgo)),
    route: route,
  );
}

class _World {
  const _World(this.db, this.store, this.uid, this.activityId);

  final LocalDb db;
  final MemoryStore store;
  final String uid;
  final String activityId;
}

Future<_World> _populated({MemoryStore? store}) async {
  final s = store ?? MemoryStore();
  final db = await _open(store: s, seed: true);
  final uid = await _registerAni(db);
  final id = await db.addActivity(
    _draft(
      uid,
      title: 'Lari Sore',
      route: const <LatLng>[LatLng(-6.2, 106.8), LatLng(-6.21, 106.81)],
    ),
  );
  final friend = db.searchUsers('').firstWhere((u) => u.uid != uid).uid;
  await db.setKudos(activityId: id, uid: friend, give: true);
  await db.addComment(
    activityId: id,
    userId: uid,
    userName: 'Ani',
    text: 'Semangat!',
  );
  await db.setFollow(me: uid, target: friend, follow: true);
  return _World(db, s, uid, id);
}

String _edit(String text, void Function(Map<String, dynamic> root) change) {
  final root = jsonDecode(text) as Map<String, dynamic>;
  change(root);
  return jsonEncode(root);
}

Matcher _appError(String message) {
  return isA<AppException>().having((e) => e.message, 'message', message);
}

void main() {
  group('Akun', () {
    test('mendaftar membuat akun dan langsung masuk', () async {
      final db = await _open();
      final me = await db.register(
        name: '  Ani  ',
        email: ' Ani@Mail.COM ',
        password: 'rahasia1',
      );

      expect(me.displayName, 'Ani');
      expect(me.email, 'ani@mail.com');
      expect(db.currentUser?.uid, me.uid);
      expect(db.userById(me.uid)?.displayName, 'Ani');
    });

    test('email yang sama ditolak walau huruf besar/kecil berbeda', () async {
      final db = await _open();
      await _registerAni(db);

      await expectLater(
        db.register(name: 'Lain', email: 'ANI@mail.com', password: 'rahasia2'),
        throwsA(_appError('Email sudah terdaftar. Silakan masuk.')),
      );
    });

    test('data pendaftaran yang tidak valid ditolak', () async {
      final db = await _open();

      await expectLater(
        db.register(name: ' ', email: 'a@b.co', password: '123456'),
        throwsA(_appError('Nama tidak boleh kosong.')),
      );
      await expectLater(
        db.register(name: 'A', email: 'salah', password: '123456'),
        throwsA(_appError('Format email tidak valid.')),
      );
      await expectLater(
        db.register(name: 'A', email: 'a@b.co', password: '123'),
        throwsA(_appError('Kata sandi terlalu lemah (minimal 6 karakter).')),
      );
      expect(db.currentUser, isNull);
    });

    test('masuk berhasil dengan kata sandi benar, gagal bila salah', () async {
      final db = await _open();
      await _registerAni(db);
      await db.logout();
      expect(db.currentUser, isNull);

      await expectLater(
        db.login(email: 'ani@mail.com', password: 'salah'),
        throwsA(_appError('Email atau kata sandi salah.')),
      );
      await expectLater(
        db.login(email: 'orang@mail.com', password: 'rahasia1'),
        throwsA(_appError('Email atau kata sandi salah.')),
      );
      await expectLater(
        db.login(email: 'bukan-email', password: 'x'),
        throwsA(_appError('Format email tidak valid.')),
      );
      expect(db.currentUser, isNull);

      final me = await db.login(email: ' ANI@mail.com ', password: 'rahasia1');
      expect(me.displayName, 'Ani');
      expect(db.currentUser?.email, 'ani@mail.com');
    });

    test('kata sandi tidak tersimpan sebagai teks biasa', () async {
      final store = MemoryStore();
      final db = await _open(store: store);
      await _registerAni(db);

      final saved = store.data['lariku_credentials']!;
      expect(saved.contains('rahasia1'), isFalse);
      expect(saved.contains('ani@mail.com'), isTrue);
    });

    test(
      'sesi bertahan setelah dimuat ulang dan hilang setelah keluar',
      () async {
        final store = MemoryStore();
        final db = await _open(store: store);
        final uid = await _registerAni(db);

        expect((await _open(store: store)).currentUser?.uid, uid);

        await db.logout();
        expect((await _open(store: store)).currentUser, isNull);
        expect(store.data.containsKey('lariku_session'), isFalse);
      },
    );

    test('mengganti nama menyalinnya ke aktivitas dan komentar', () async {
      final db = await _open();
      final uid = await _registerAni(db);
      final id = await db.addActivity(_draft(uid));
      await db.addComment(
        activityId: id,
        userId: uid,
        userName: 'Ani',
        text: 'Mantap',
      );

      await db.updateProfile(
        uid: uid,
        displayName: ' Ani Baru ',
        bio: ' Halo ',
      );

      expect(db.userById(uid)?.displayName, 'Ani Baru');
      expect(db.userById(uid)?.bio, 'Halo');
      expect(db.activityById(id)?.userName, 'Ani Baru');
      expect(db.commentsFor(id).single.userName, 'Ani Baru');
      expect(db.currentUser?.displayName, 'Ani Baru');
    });

    test('updateDisplayName mengubah nama akun yang sedang masuk', () async {
      final db = await _open();
      final uid = await _registerAni(db);

      await db.updateDisplayName('Budi');

      expect(db.userById(uid)?.displayName, 'Budi');
      expect(db.currentUser?.displayName, 'Budi');
    });
  });

  group('Pencarian pengguna', () {
    test(
      'tanpa kata kunci, yang terbaru mendaftar tampil paling atas',
      () async {
        var clock = _now;
        final db = await _open(clock: () => clock);
        await db.register(name: 'Ani', email: 'a@mail.com', password: '123456');
        clock = clock.add(const Duration(minutes: 5));
        await db.register(
          name: 'Budi',
          email: 'b@mail.com',
          password: '123456',
        );
        clock = clock.add(const Duration(minutes: 5));
        await db.register(
          name: 'Cici',
          email: 'c@mail.com',
          password: '123456',
        );

        final names = db.searchUsers('').map((u) => u.displayName).toList();
        expect(names, <String>['Cici', 'Budi', 'Ani']);
      },
    );

    test(
      'kata kunci dicocokkan di bagian mana pun nama, tanpa peduli huruf',
      () async {
        final db = await _open();
        await db.register(
          name: 'Rina Pratama',
          email: 'r@mail.com',
          password: '123456',
        );
        await db.register(
          name: 'Budi',
          email: 'b@mail.com',
          password: '123456',
        );

        expect(db.searchUsers('rIN').map((u) => u.displayName), <String>[
          'Rina Pratama',
        ]);
        expect(db.searchUsers('prat').length, 1);
        expect(db.searchUsers('zzz'), isEmpty);
      },
    );
  });

  group('Aktivitas', () {
    test(
      'menyimpan aktivitas dengan ID baru dan menolak akun tak dikenal',
      () async {
        final db = await _open();
        final uid = await _registerAni(db);

        final id = await db.addActivity(_draft(uid, title: 'Lari Sore'));
        expect(id, isNotEmpty);
        expect(db.activityById(id)?.title, 'Lari Sore');
        expect(db.activityById(id)?.kudosBy, isEmpty);

        await expectLater(
          db.addActivity(_draft('tidak-ada')),
          throwsA(_appError('Akun tidak ditemukan. Silakan masuk kembali.')),
        );
        expect(db.allActivities().length, 1);
      },
    );

    test(
      'rute panjang disederhanakan dan dibulatkan seperti yang disimpan',
      () async {
        final store = MemoryStore();
        final db = await _open(store: store);
        final uid = await _registerAni(db);
        final route = List<LatLng>.generate(
          1200,
          (i) => LatLng(-6.2 + i * 0.000013, 106.8 + i * 0.000017),
        );

        final id = await db.addActivity(_draft(uid, route: route));
        final saved = db.activityById(id)!.route;

        expect(saved.length, LocalDb.maxRoutePoints);
        expect(saved.first.latitude, closeTo(-6.2, 0.00001));
        expect(saved.last.longitude, closeTo(106.8 + 1199 * 0.000017, 0.00001));

        // Isi memori sama persis dengan isi penyimpanan setelah dimuat ulang.
        final reloaded = (await _open(store: store)).activityById(id)!.route;
        expect(reloaded, saved);
      },
    );

    test(
      'daftar aktivitas urut dari yang terbaru, lengkap dengan jumlah komentar',
      () async {
        final db = await _open();
        final uid = await _registerAni(db);
        final older = await db.addActivity(
          _draft(uid, title: 'Lama', hoursAgo: 30),
        );
        final newer = await db.addActivity(
          _draft(uid, title: 'Baru', hoursAgo: 2),
        );
        await db.addComment(
          activityId: older,
          userId: uid,
          userName: 'Ani',
          text: 'Satu',
        );

        final list = db.allActivities();
        expect(list.map((a) => a.id), <String>[newer, older]);
        expect(list.last.commentsCount, 1);
        expect(list.first.commentsCount, 0);
      },
    );

    test('menghapus aktivitas ikut menghapus komentarnya', () async {
      final store = MemoryStore();
      final db = await _open(store: store);
      final uid = await _registerAni(db);
      final id = await db.addActivity(_draft(uid));
      await db.addComment(
        activityId: id,
        userId: uid,
        userName: 'Ani',
        text: 'Halo',
      );

      await db.deleteActivity(id);

      expect(db.activityById(id), isNull);
      expect(db.commentsFor(id), isEmpty);
      expect(store.data['lariku_comments'], '{}');
    });

    test(
      'kudos: memberi, tidak ganda, mencabut, dan aktivitas hilang',
      () async {
        final db = await _open();
        final uid = await _registerAni(db);
        final id = await db.addActivity(_draft(uid));

        await db.setKudos(activityId: id, uid: 'u2', give: true);
        await db.setKudos(activityId: id, uid: 'u2', give: true);
        await db.setKudos(activityId: id, uid: 'u3', give: true);
        expect(db.activityById(id)?.kudosBy, <String>['u2', 'u3']);

        await db.setKudos(activityId: id, uid: 'u2', give: false);
        await db.setKudos(activityId: id, uid: 'u9', give: false);
        expect(db.activityById(id)?.kudosBy, <String>['u3']);

        await expectLater(
          db.setKudos(activityId: 'hilang', uid: 'u2', give: true),
          throwsA(isA<AppException>()),
        );
      },
    );
  });

  group('Komentar', () {
    test('menambah, menghitung, dan menghapus komentar', () async {
      final db = await _open();
      final uid = await _registerAni(db);
      final id = await db.addActivity(_draft(uid));

      await db.addComment(
        activityId: id,
        userId: uid,
        userName: 'Ani',
        text: '  Pertama  ',
      );
      await db.addComment(
        activityId: id,
        userId: 'u2',
        userName: 'Budi',
        text: 'Kedua',
      );

      var comments = db.commentsFor(id);
      expect(comments.map((c) => c.text), <String>['Pertama', 'Kedua']);
      expect(db.activityById(id)?.commentsCount, 2);

      await db.deleteComment(activityId: id, commentId: comments.first.id);
      await db.deleteComment(activityId: id, commentId: 'tidak-ada');

      comments = db.commentsFor(id);
      expect(comments.map((c) => c.text), <String>['Kedua']);
      expect(db.activityById(id)?.commentsCount, 1);
    });

    test('komentar kosong dan aktivitas yang tidak ada ditolak', () async {
      final db = await _open();
      final uid = await _registerAni(db);
      final id = await db.addActivity(_draft(uid));

      await expectLater(
        db.addComment(
          activityId: id,
          userId: uid,
          userName: 'Ani',
          text: '   ',
        ),
        throwsA(_appError('Komentar tidak boleh kosong.')),
      );
      await expectLater(
        db.addComment(
          activityId: 'hilang',
          userId: uid,
          userName: 'Ani',
          text: 'x',
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('Mengikuti', () {
    test('mengikuti, berhenti mengikuti, dan menghitung', () async {
      final db = await _open();

      await db.setFollow(me: 'a', target: 'b', follow: true);
      await db.setFollow(me: 'a', target: 'b', follow: true);
      await db.setFollow(me: 'c', target: 'b', follow: true);
      await db.setFollow(me: 'a', target: 'd', follow: true);
      await db.setFollow(me: 'a', target: 'a', follow: true);

      expect(db.followingOf('a'), <String>{'b', 'd'});
      expect(db.followersCount('b'), 2);
      expect(db.followingCount('a'), 2);
      expect(db.followersCount('a'), 0);

      await db.setFollow(me: 'a', target: 'b', follow: false);
      expect(db.followingOf('a'), <String>{'d'});
      expect(db.followersCount('b'), 1);
    });
  });

  group('Pengamatan (watch)', () {
    test(
      'mengirim nilai awal, mengirim ulang saat berubah, berhenti saat dibatalkan',
      () async {
        final db = await _open();
        final events = <int>[];
        final sub = db
            .watch<int>(() => db.followersCount('b'))
            .listen(events.add);

        await Future<void>.delayed(Duration.zero);
        expect(events, <int>[0]);

        await db.setFollow(me: 'a', target: 'b', follow: true);
        await Future<void>.delayed(Duration.zero);
        expect(events, <int>[0, 1]);

        await sub.cancel();
        await db.setFollow(me: 'c', target: 'b', follow: true);
        await Future<void>.delayed(Duration.zero);
        expect(events, <int>[0, 1]);
      },
    );

    test(
      'satu aliran boleh didengarkan berkali-kali oleh banyak pendengar',
      () async {
        final db = await _open();
        final stream = db.watch<int>(() => db.followersCount('b'));
        final first = <int>[];
        final second = <int>[];

        final subA = stream.listen(first.add);
        final subB = stream.listen(second.add);
        await Future<void>.delayed(Duration.zero);
        await subA.cancel();
        await db.setFollow(me: 'a', target: 'b', follow: true);
        await Future<void>.delayed(Duration.zero);
        final subC = stream.listen(first.add);
        await Future<void>.delayed(Duration.zero);

        expect(first, <int>[0, 1]);
        expect(second, <int>[0, 1]);
        await subB.cancel();
        await subC.cancel();
      },
    );

    test('kesalahan saat membaca dikirim sebagai error aliran', () async {
      final db = await _open();
      final errors = <Object>[];
      final sub = db
          .watch<int>(() => throw StateError('gagal'))
          .listen((_) {}, onError: errors.add);

      await Future<void>.delayed(Duration.zero);
      expect(errors.single, isA<StateError>());
      await sub.cancel();
    });
  });

  group('Penyimpanan', () {
    test('pertama kali dibuka, data contoh dimuat dan disimpan', () async {
      final store = MemoryStore();
      final db = await _open(store: store, seed: true);

      expect(db.allActivities(), isNotEmpty);
      expect(db.searchUsers('').length, 5);
      for (final key in <String>[
        'lariku_users',
        'lariku_credentials',
        'lariku_activities',
        'lariku_comments',
        'lariku_follows',
        'lariku_seed_version',
      ]) {
        expect(store.data.containsKey(key), isTrue, reason: key);
      }
      expect(store.data['lariku_seed_version'], '1');
      expect(store.data.containsKey('lariku_session'), isFalse);
    });

    test('tanpa data contoh, database mulai kosong', () async {
      final db = await _open(seed: false);
      expect(db.allActivities(), isEmpty);
      expect(db.searchUsers(''), isEmpty);
    });

    test(
      'bentuk JSON yang disimpan sesuai yang dijelaskan di panduan',
      () async {
        final store = MemoryStore();
        final db = await _open(store: store);
        final uid = await _registerAni(db);
        final id = await db.addActivity(
          _draft(
            uid,
            route: const <LatLng>[LatLng(-6.2, 106.8), LatLng(-6.21, 106.81)],
          ),
        );
        await db.setKudos(activityId: id, uid: 'u2', give: true);

        final users = jsonDecode(store.data['lariku_users']!) as List<dynamic>;
        expect((users.single as Map<String, dynamic>)['displayName'], 'Ani');

        final acts =
            jsonDecode(store.data['lariku_activities']!) as List<dynamic>;
        final first = acts.single as Map<String, dynamic>;
        expect(first['type'], 'run');
        expect(first['kudosBy'], <String>['u2']);
        expect(first['route'], <int>[-620000, 10680000, -621000, 10681000]);
        expect(first['startTime'], isA<int>());

        expect(store.data['lariku_session'], uid);
      },
    );

    test('data yang rusak membuat database kembali ke data contoh', () async {
      final store = MemoryStore();
      store.data['lariku_users'] = 'ini bukan json';
      store.data['lariku_activities'] = '[]';

      final db = await _open(store: store, seed: true);

      expect(db.searchUsers('').length, 5);
      expect(db.allActivities(), isNotEmpty);
      // Isi penyimpanan sudah diperbaiki.
      expect(jsonDecode(store.data['lariku_users']!), isA<List<dynamic>>());
    });

    test('semua perubahan terbaca kembali setelah dimuat ulang', () async {
      final store = MemoryStore();
      final db = await _open(store: store);
      final uid = await _registerAni(db);
      final a = await db.addActivity(_draft(uid, title: 'A', hoursAgo: 5));
      final b = await db.addActivity(_draft(uid, title: 'B', hoursAgo: 1));
      await db.setKudos(activityId: a, uid: 'u2', give: true);
      await db.addComment(
        activityId: b,
        userId: uid,
        userName: 'Ani',
        text: 'Halo',
      );
      await db.setFollow(me: uid, target: 'u2', follow: true);
      await db.deleteActivity(a);

      final again = await _open(store: store);

      expect(again.allActivities().map((x) => x.title), <String>['B']);
      expect(again.activityById(b)?.commentsCount, 1);
      expect(again.commentsFor(b).single.text, 'Halo');
      expect(again.followingOf(uid), <String>{'u2'});
      expect(again.currentUser?.displayName, 'Ani');

      // Akun yang dibuat sebelumnya masih bisa dipakai masuk.
      await again.logout();
      final me = await again.login(email: 'ani@mail.com', password: 'rahasia1');
      expect(me.uid, uid);
    });

    test(
      'banyak perubahan beruntun tanpa menunggu tetap tersimpan lengkap',
      () async {
        final store = MemoryStore();
        final db = await _open(store: store);
        final uid = await _registerAni(db);

        final ids = await Future.wait(<Future<String>>[
          for (var i = 0; i < 8; i++)
            db.addActivity(_draft(uid, title: 'Aktivitas $i', hoursAgo: i + 1)),
        ]);
        await Future.wait(<Future<void>>[
          for (final id in ids)
            db.setKudos(activityId: id, uid: 'u2', give: true),
        ]);

        final again = await _open(store: store);
        expect(again.allActivities().length, 8);
        expect(again.allActivities().every((a) => a.kudosCount == 1), isTrue);
      },
    );

    test(
      'gagal menyimpan: ada pesan error dan aktivitas batal ditambahkan',
      () async {
        final store = _FlakyStore();
        final db = await _open(store: store);
        final uid = await _registerAni(db);

        store.failWrites = true;
        await expectLater(
          db.addActivity(_draft(uid)),
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'message',
              contains('tidak dapat disimpan'),
            ),
          ),
        );
        expect(db.allActivities(), isEmpty);

        // Setelah penyimpanan pulih, semuanya berjalan normal lagi.
        store.failWrites = false;
        await db.addActivity(_draft(uid, title: 'Berhasil'));
        final again = await _open(store: store);
        expect(again.allActivities().single.title, 'Berhasil');
      },
    );

    test('penulisan yang gagal dicoba lagi pada penyimpanan berikutnya', () async {
      final store = _FlakyStore();
      final db = await _open(store: store);
      final uid = await _registerAni(db);
      final id = await db.addActivity(_draft(uid));

      store.failWrites = true;
      await expectLater(
        db.setKudos(activityId: id, uid: 'u2', give: true),
        throwsA(isA<AppException>()),
      );

      // Perubahan berikutnya hanya menandai kunci "follows", tetapi kudos yang
      // gagal tadi ikut tertulis karena kuncinya masih ditandai belum tersimpan.
      store.failWrites = false;
      await db.setFollow(me: uid, target: 'u2', follow: true);

      final again = await _open(store: store);
      expect(again.activityById(id)?.kudosBy, <String>['u2']);
      expect(again.followingOf(uid), <String>{'u2'});
    });

    test('atur ulang menghapus semua data dan keluar dari akun', () async {
      final store = MemoryStore();
      final db = await _open(store: store, seed: true);
      final uid = await _registerAni(db);
      await db.addActivity(_draft(uid, title: 'Milik Ani'));

      await db.resetAll();

      expect(db.currentUser, isNull);
      expect(db.allActivities().any((a) => a.title == 'Milik Ani'), isFalse);
      expect(db.searchUsers('ani'), isEmpty);
      expect(db.searchUsers('').length, 5);
      expect(store.data.containsKey('lariku_session'), isFalse);
      expect(jsonDecode(store.data['lariku_credentials']!), isEmpty);
    });
  });

  group('Cadangan', () {
    test('ekspor memuat semua koleksi, tanpa sesi login', () async {
      final w = await _populated();

      final root = jsonDecode(w.db.exportJson()) as Map<String, dynamic>;

      expect(root['app'], 'lariku');
      expect(root['format'], 1);
      expect(
        DateTime.parse(root['exportedAt'] as String).isAtSameMomentAs(_now),
        isTrue,
      );
      final data = root['data'] as Map<String, dynamic>;
      expect(
        data.keys,
        unorderedEquals(<String>[
          'users',
          'credentials',
          'activities',
          'comments',
          'follows',
        ]),
      );
      expect(data.containsKey('session'), isFalse);
      // Kata sandi tetap berupa hash, bukan teks biasa.
      expect(jsonEncode(data['credentials']), isNot(contains('rahasia1')));
    });

    test('isi cadangan sama dengan isi yang ditulis ke penyimpanan', () async {
      final w = await _populated();

      final data =
          (jsonDecode(w.db.exportJson()) as Map<String, dynamic>)['data']
              as Map<String, dynamic>;

      for (final name in data.keys) {
        expect(
          jsonDecode(w.store.data['lariku_$name']!),
          data[name],
          reason: 'koleksi $name',
        );
      }
    });

    test('dipulihkan ke database lain, hasilnya sama persis', () async {
      final w = await _populated();
      final text = w.db.exportJson();

      final otherStore = MemoryStore();
      final other = await _open(store: otherStore);
      final summary = await other.importJson(text);

      expect(other.exportJson(), text);
      expect(summary.users, 6); // 5 contoh + Ani
      expect(summary.comments, greaterThan(0));
      expect(other.activityById(w.activityId)?.title, 'Lari Sore');
      expect(other.activityById(w.activityId)?.route.length, 2);
      expect(other.commentsFor(w.activityId).single.text, 'Semangat!');

      // Cadangan itu ikut tersimpan: dibuka ulang, isinya tetap sama.
      final again = await _open(store: otherStore);
      expect(again.exportJson(), text);
    });

    test(
      'akun dari cadangan bisa dipakai masuk dengan kata sandi lama',
      () async {
        final w = await _populated();
        final other = await _open();

        await other.importJson(w.db.exportJson());

        final me = await other.login(
          email: 'ani@mail.com',
          password: 'rahasia1',
        );
        expect(me.uid, w.uid);
        await expectLater(
          other.login(email: 'ani@mail.com', password: 'salah'),
          throwsA(isA<AppException>()),
        );
      },
    );

    test('pemulihan mengganti data yang ada dan mengeluarkan akun', () async {
      final w = await _populated();
      final emptyBackup = (await _open()).exportJson();

      await w.db.importJson(emptyBackup);

      expect(w.db.currentUser, isNull);
      expect(w.db.allActivities(), isEmpty);
      expect(w.db.searchUsers(''), isEmpty);
      expect(w.store.data.containsKey('lariku_session'), isFalse);
      expect(jsonDecode(w.store.data['lariku_users']!), isEmpty);
    });

    test('inspectBackup menghitung isi tanpa mengubah apa pun', () async {
      final w = await _populated();
      final before = w.db.exportJson();

      final summary = LocalDb.inspectBackup(before);

      expect(summary.users, 6);
      expect(summary.activities, w.db.allActivities().length);
      var comments = 0;
      for (final a in w.db.allActivities()) {
        comments += w.db.commentsFor(a.id).length;
      }
      expect(comments, greaterThan(1));
      expect(summary.comments, comments);
      expect(summary.follows, greaterThan(0));
      expect(summary.exportedAt, _now);
      expect(w.db.exportJson(), before);
    });

    test(
      'hubungan mengikuti yang bukan teks dilewati, bukan menggagalkan',
      () async {
        final w = await _populated();
        final text = _edit(w.db.exportJson(), (r) {
          final data = r['data'] as Map<String, dynamic>;
          data['follows'] = <Object?>['u1|u2', 42, null];
        });

        final summary = LocalDb.inspectBackup(text);

        expect(summary.follows, 1);
      },
    );

    test('waktu pembuatan yang tidak terbaca diabaikan', () async {
      final w = await _populated();
      final text = _edit(w.db.exportJson(), (r) => r['exportedAt'] = 'kemarin');

      expect(LocalDb.inspectBackup(text).exportedAt, isNull);
    });

    group('cadangan yang tidak valid ditolak dan data tetap utuh', () {
      Future<void> expectRejected(String text, String messagePart) async {
        final w = await _populated();
        final before = w.db.exportJson();

        await expectLater(
          w.db.importJson(text),
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'message',
              contains(messagePart),
            ),
          ),
        );
        expect(w.db.exportJson(), before);
        expect(w.db.currentUser?.uid, w.uid);
        // inspectBackup menolak dengan pesan yang sama.
        expect(
          () => LocalDb.inspectBackup(text),
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'message',
              contains(messagePart),
            ),
          ),
        );
      }

      Future<String> valid() async => (await _populated()).db.exportJson();

      test(
        'bukan JSON',
        () => expectRejected('ini bukan json', 'tidak dapat dibaca'),
      );

      test(
        'JSON tetapi bukan objek',
        () => expectRejected('[]', 'bukan cadangan Lariku'),
      );

      test('dibuat aplikasi lain', () {
        return expectRejected(
          '{"app":"aplikasi-lain","format":1,"data":{}}',
          'bukan cadangan Lariku',
        );
      });

      test('format lebih baru dari yang dipahami', () async {
        final text = _edit(await valid(), (r) => r['format'] = 2);
        await expectRejected(text, 'lebih baru');
      });

      test('format tidak ada', () async {
        final text = _edit(await valid(), (r) => r.remove('format'));
        await expectRejected(text, 'rusak');
      });

      test('bagian data tidak ada', () async {
        final text = _edit(await valid(), (r) => r.remove('data'));
        await expectRejected(text, 'rusak');
      });

      test('salah satu koleksi tidak ada', () async {
        final text = _edit(
          await valid(),
          (r) => (r['data'] as Map<String, dynamic>).remove('follows'),
        );
        await expectRejected(text, 'rusak');
      });

      test('koleksi bertipe salah', () async {
        final text = _edit(
          await valid(),
          (r) => (r['data'] as Map<String, dynamic>)['users'] =
              <String, dynamic>{},
        );
        await expectRejected(text, 'rusak');
      });

      test('aktivitas tanpa ID', () async {
        final text = _edit(await valid(), (r) {
          final data = r['data'] as Map<String, dynamic>;
          final first =
              (data['activities'] as List<dynamic>).first
                  as Map<String, dynamic>;
          first.remove('id');
        });
        await expectRejected(text, 'rusak');
      });

      test('komentar bukan daftar', () async {
        final text = _edit(
          await valid(),
          (r) => (r['data'] as Map<String, dynamic>)['comments'] =
              <String, dynamic>{'x': 'bukan daftar'},
        );
        await expectRejected(text, 'rusak');
      });
    });

    test(
      'gagal menyimpan: data lama dikembalikan, termasuk sesi login',
      () async {
        final store = _FlakyStore();
        final w = await _populated(store: store);
        final otherBackup = (await _open(seed: true)).exportJson();
        final before = w.db.exportJson();

        store.failWrites = true;
        await expectLater(
          w.db.importJson(otherBackup),
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'message',
              contains('tidak dapat disimpan'),
            ),
          ),
        );

        expect(w.db.exportJson(), before);
        expect(w.db.currentUser?.uid, w.uid);

        // Setelah penyimpanan pulih, penulisan berikutnya melengkapi isi lama.
        store.failWrites = false;
        await w.db.setFollow(me: w.uid, target: 'u-lain', follow: true);

        final again = await _open(store: store);
        expect(again.currentUser?.uid, w.uid);
        expect(again.activityById(w.activityId)?.title, 'Lari Sore');
        expect(again.commentsFor(w.activityId).single.text, 'Semangat!');
        expect(again.followingOf(w.uid), contains('u-lain'));
      },
    );
  });
}
