import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_lokasi2/core/app_exception.dart';
import 'package:flutter_lokasi2/data/key_value_store.dart';
import 'package:flutter_lokasi2/data/local_db.dart';
import 'package:flutter_lokasi2/models/activity.dart';
import 'package:flutter_lokasi2/models/activity_type.dart';
import 'package:flutter_lokasi2/services/directory_file_storage.dart';
import 'package:flutter_lokasi2/services/export_service.dart';
import 'package:flutter_lokasi2/services/file_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;

final DateTime _now = DateTime(2026, 11, 10, 18, 44, 5);

class _MemoryFiles implements FileStorage {
  final Map<String, String> files = <String, String>{};
  final Map<String, DateTime> modified = <String, DateTime>{};
  int _clock = 0;

  @override
  bool get isSupported => true;

  @override
  Future<String> folderPath() async => '/memori/Lariku';

  @override
  Future<String> write(String name, String content) async {
    files[name] = content;
    modified[name] = DateTime(2026, 11, 10).add(Duration(minutes: _clock++));
    return '/memori/Lariku/$name';
  }

  @override
  Future<String> read(String name) async {
    final content = files[name];
    if (content == null) throw const AppException('Berkas tidak ditemukan.');
    return content;
  }

  @override
  Future<List<StoredFile>> list({
    String prefix = '',
    String suffix = '',
  }) async {
    final found = <StoredFile>[
      for (final name in files.keys)
        if (name.startsWith(prefix) && name.endsWith(suffix))
          StoredFile(
            name: name,
            sizeBytes: files[name]!.length,
            modified: modified[name]!,
          ),
    ];
    found.sort((a, b) => b.modified.compareTo(a.modified));
    return found;
  }

  @override
  Future<void> delete(String name) async {
    files.remove(name);
    modified.remove(name);
  }
}

Matcher _appError(String part) {
  return isA<AppException>().having(
    (e) => e.message,
    'message',
    contains(part),
  );
}

Future<LocalDb> _db({bool seed = true}) async {
  final db = LocalDb(now: () => _now, random: Random(1));
  await db.init(store: MemoryStore(), seed: seed);
  return db;
}

Activity _activity({List<LatLng>? route}) {
  return Activity(
    id: 'a1',
    userId: 'u1',
    userName: 'Ani',
    title: 'Lari Pagi',
    type: ActivityType.run,
    distanceM: 5000,
    durationS: 1500,
    startTime: DateTime(2026, 11, 3, 6, 30),
    route: route ?? const <LatLng>[LatLng(-6.2, 106.8), LatLng(-6.21, 106.81)],
  );
}

void main() {
  group('ExportService: cadangan', () {
    late LocalDb db;
    late _MemoryFiles files;
    late ExportService service;

    setUp(() async {
      db = await _db();
      files = _MemoryFiles();
      service = ExportService(db: db, storage: files, now: () => _now);
    });

    test('nama berkas memuat tanggal dan jam pembuatan', () {
      expect(service.backupFileName(), 'lariku_cadangan_20261110_184405.json');
    });

    test('saveBackup menulis cadangan yang bisa dibaca kembali', () async {
      final saved = await service.saveBackup();

      expect(saved.name, 'lariku_cadangan_20261110_184405.json');
      expect(saved.path, '/memori/Lariku/lariku_cadangan_20261110_184405.json');
      expect(await service.readBackup(saved.name), service.buildBackup());
      expect(
        LocalDb.inspectBackup(files.files[saved.name]!).users,
        db.searchUsers('').length,
      );
    });

    test('listBackups hanya memuat cadangan, yang terbaru di atas', () async {
      files.files['catatan.txt'] = 'bukan cadangan';
      files.files['lariku_run_20261103_0630.gpx'] = '<gpx/>';
      files.files['lariku_cadangan_20261101_080000.json'] = '{}';
      files.modified['lariku_cadangan_20261101_080000.json'] = DateTime(2026);
      files.files['lariku_cadangan_20261105_080000.json'] = '{}';
      files.modified['lariku_cadangan_20261105_080000.json'] = DateTime(
        2026,
        2,
      );

      final names = (await service.listBackups()).map((f) => f.name).toList();

      expect(names, <String>[
        'lariku_cadangan_20261105_080000.json',
        'lariku_cadangan_20261101_080000.json',
      ]);
    });

    test('hanya berkas cadangan yang boleh dibaca atau dihapus', () async {
      files.files['catatan.txt'] = 'rahasia';

      await expectLater(
        service.readBackup('catatan.txt'),
        throwsA(_appError('bukan berkas cadangan')),
      );
      await expectLater(
        service.deleteBackup('catatan.txt'),
        throwsA(_appError('bukan berkas cadangan')),
      );
      await expectLater(
        service.readBackup('../lariku_cadangan_x.json.txt'),
        throwsA(_appError('bukan berkas cadangan')),
      );
      expect(files.files.containsKey('catatan.txt'), isTrue);
    });

    test('deleteBackup menghapus berkas', () async {
      final saved = await service.saveBackup();

      await service.deleteBackup(saved.name);

      expect(await service.listBackups(), isEmpty);
    });

    test('restoreBackup mengganti data dengan isi cadangan', () async {
      final saved = await service.saveBackup();
      final text = await service.readBackup(saved.name);

      final other = await _db(seed: false);
      final otherService = ExportService(db: other, storage: files);
      expect(other.allActivities(), isEmpty);

      final summary = await otherService.restoreBackup(text);

      expect(summary.activities, db.allActivities().length);
      expect(other.allActivities().length, db.allActivities().length);
      expect(otherService.inspectBackup(text).users, summary.users);
    });

    test(
      'cadangan rusak ditolak oleh inspectBackup dan restoreBackup',
      () async {
        expect(
          () => service.inspectBackup('bukan json'),
          throwsA(_appError('tidak dapat dibaca')),
        );
        await expectLater(
          service.restoreBackup('bukan json'),
          throwsA(_appError('tidak dapat dibaca')),
        );
        expect(db.allActivities(), isNotEmpty);
      },
    );
  });

  group('ExportService: GPX', () {
    late _MemoryFiles files;
    late ExportService service;

    setUp(() async {
      files = _MemoryFiles();
      service = ExportService(db: await _db(), storage: files, now: () => _now);
    });

    test('nama berkas memuat jenis dan waktu mulai aktivitas', () {
      expect(service.gpxFileName(_activity()), 'lariku_run_20261103_0630.gpx');
    });

    test('saveGpx menulis dokumen GPX ke penyimpanan', () async {
      final saved = await service.saveGpx(_activity());

      expect(saved.name, 'lariku_run_20261103_0630.gpx');
      expect(files.files[saved.name], service.buildGpx(_activity()));
      expect(files.files[saved.name], contains('<gpx version="1.1"'));
    });

    test('rute kosong: ditolak dan tidak ada berkas yang ditulis', () async {
      await expectLater(
        service.saveGpx(_activity(route: const <LatLng>[])),
        throwsA(_appError('tidak punya rute')),
      );
      expect(files.files, isEmpty);
    });
  });

  group('UnsupportedFileStorage (web)', () {
    test(
      'tidak mendukung berkas dan semua operasi ditolak dengan pesan jelas',
      () async {
        const storage = UnsupportedFileStorage();
        final service = ExportService(db: await _db(), storage: storage);

        expect(service.canSaveFiles, isFalse);
        await expectLater(
          service.saveBackup(),
          throwsA(_appError('versi web')),
        );
        await expectLater(
          service.listBackups(),
          throwsA(_appError('versi web')),
        );
        await expectLater(
          service.folderPath(),
          throwsA(_appError('versi web')),
        );
        await expectLater(
          service.saveGpx(_activity()),
          throwsA(_appError('versi web')),
        );
        // Menyalin ke papan klip tetap bisa karena hanya membuat teks.
        expect(service.buildBackup(), contains('"app":"lariku"'));
        expect(service.buildGpx(_activity()), contains('<gpx'));
      },
    );
  });

  group('DirectoryFileStorage', () {
    late Directory root;
    late Directory target;
    late DirectoryFileStorage storage;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('lariku_test_');
      target = Directory('${root.path}${Platform.pathSeparator}Lariku');
      storage = DirectoryFileStorage(() async => target);
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('mendukung berkas dan membuat folder tujuan bila belum ada', () async {
      expect(storage.isSupported, isTrue);
      expect(await target.exists(), isFalse);

      final path = await storage.write('a.json', '{}');

      expect(await target.exists(), isTrue);
      expect(path, '${target.path}${Platform.pathSeparator}a.json');
      expect(await storage.folderPath(), target.path);
    });

    test('tulis lalu baca kembali, termasuk huruf non-ASCII', () async {
      const text = '{"judul":"Lari pagi ✓ café"}';

      await storage.write('a.json', text);

      expect(await storage.read('a.json'), text);
      // Disimpan sebagai UTF-8 sungguhan.
      expect(
        await File(
          '${target.path}${Platform.pathSeparator}a.json',
        ).readAsBytes(),
        utf8.encode(text),
      );
    });

    test('menulis ke nama yang sama menimpa isi lama', () async {
      await storage.write('a.json', 'lama yang panjang sekali');
      await storage.write('a.json', 'baru');

      expect(await storage.read('a.json'), 'baru');
    });

    test('membaca berkas yang tidak ada memberi pesan jelas', () async {
      await expectLater(
        storage.read('tidak-ada.json'),
        throwsA(_appError('tidak ditemukan')),
      );
    });

    test(
      'list: menyaring awalan dan akhiran, mengabaikan folder, terbaru dulu',
      () async {
        await storage.write('lariku_cadangan_1.json', 'satu');
        await storage.write('lariku_cadangan_2.json', 'dua!');
        await storage.write('catatan.txt', 'x');
        await storage.write('lariku_run_1.gpx', 'x');
        await storage.write('lariku_cadangan_3.json.bak', 'x');
        await Directory(
          '${target.path}${Platform.pathSeparator}lariku_cadangan_folder.json',
        ).create();
        await File(
          '${target.path}${Platform.pathSeparator}lariku_cadangan_1.json',
        ).setLastModified(DateTime(2026, 1, 1));
        await File(
          '${target.path}${Platform.pathSeparator}lariku_cadangan_2.json',
        ).setLastModified(DateTime(2026, 6, 1));

        final found = await storage.list(
          prefix: 'lariku_cadangan_',
          suffix: '.json',
        );

        expect(found.map((f) => f.name).toList(), <String>[
          'lariku_cadangan_2.json',
          'lariku_cadangan_1.json',
        ]);
        expect(found.first.sizeBytes, 4);
        expect(found.first.modified, DateTime(2026, 6, 1));
        expect((await storage.list()).length, 5);
      },
    );

    test('list pada folder yang belum ada memberi daftar kosong', () async {
      expect(await storage.list(), isEmpty);
    });

    test(
      'delete menghapus berkas, dan berkas yang tidak ada dibiarkan',
      () async {
        await storage.write('a.json', 'x');

        await storage.delete('a.json');
        await storage.delete('a.json');

        expect(await storage.list(), isEmpty);
      },
    );

    test('nama berkas yang berbahaya ditolak', () async {
      for (final name in <String>[
        '../keluar.json',
        'sub/a.json',
        r'sub\a.json',
        '.tersembunyi',
        '..',
        '',
        'a b.json',
      ]) {
        await expectLater(
          storage.write(name, 'x'),
          throwsA(_appError('tidak valid')),
          reason: 'write "$name"',
        );
        await expectLater(
          storage.read(name),
          throwsA(_appError('tidak valid')),
          reason: 'read "$name"',
        );
        await expectLater(
          storage.delete(name),
          throwsA(_appError('tidak valid')),
          reason: 'delete "$name"',
        );
      }
      expect(await root.list().toList(), isEmpty);
    });

    test('kegagalan sistem berkas menjadi AppException', () async {
      // Folder tujuan berupa berkas biasa, jadi tidak bisa dibuat sebagai folder.
      final blocker = File('${root.path}${Platform.pathSeparator}Lariku');
      await blocker.writeAsString('saya berkas');

      await expectLater(
        storage.write('a.json', 'x'),
        throwsA(_appError('gagal')),
      );
      await expectLater(storage.list(), throwsA(_appError('gagal')));
    });
  });
}
