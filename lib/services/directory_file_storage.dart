import 'dart:io';

import '../core/app_exception.dart';
import 'file_storage.dart';

/// [FileStorage] yang menyimpan berkas sebagai file biasa di sebuah folder.
///
/// File ini memakai `dart:io`, jadi hanya boleh diimpor lewat
/// `file_storage_io.dart` (yang tidak ikut dibangun untuk web).
class DirectoryFileStorage implements FileStorage {
  /// [resolve] memberi folder tujuan. Folder dibuat bila belum ada.
  DirectoryFileStorage(this._resolve);

  final Future<Directory> Function() _resolve;

  // Nama berkas yang aman: tanpa garis miring, tanpa titik di depan.
  static final RegExp _safeName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');

  @override
  bool get isSupported => true;

  Future<Directory> _directory() async {
    final dir = await _resolve();
    await dir.create(recursive: true);
    return dir;
  }

  /// Memeriksa nama berkas lebih dulu (sebelum menyentuh sistem berkas), lalu
  /// mengembalikan File di dalam folder tujuan.
  Future<File> _fileFor(String name) async {
    if (!_safeName.hasMatch(name)) {
      throw const AppException('Nama berkas tidak valid.');
    }
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  /// Mengubah kegagalan sistem berkas menjadi pesan yang mudah dibaca.
  Future<T> _guard<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } on FileSystemException catch (e) {
      final reason = e.osError?.message ?? e.message;
      throw AppException('$action gagal: $reason');
    }
  }

  @override
  Future<String> folderPath() =>
      _guard('Membuka folder', () async => (await _directory()).path);

  @override
  Future<String> write(String name, String content) {
    return _guard('Menyimpan berkas', () async {
      final file = await _fileFor(name);
      await file.writeAsString(content, flush: true);
      return file.path;
    });
  }

  @override
  Future<String> read(String name) {
    return _guard('Membaca berkas', () async {
      final file = await _fileFor(name);
      if (!await file.exists()) {
        throw const AppException('Berkas tidak ditemukan.');
      }
      return file.readAsString();
    });
  }

  @override
  Future<List<StoredFile>> list({String prefix = '', String suffix = ''}) {
    return _guard('Membaca daftar berkas', () async {
      final dir = await _directory();
      final found = <StoredFile>[];

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith(prefix) || !name.endsWith(suffix)) continue;

        final stat = await entity.stat();
        found.add(
          StoredFile(name: name, sizeBytes: stat.size, modified: stat.modified),
        );
      }

      found.sort((a, b) {
        final byTime = b.modified.compareTo(a.modified);
        return byTime != 0 ? byTime : a.name.compareTo(b.name);
      });
      return found;
    });
  }

  @override
  Future<void> delete(String name) {
    return _guard('Menghapus berkas', () async {
      final file = await _fileFor(name);
      if (await file.exists()) await file.delete();
    });
  }
}
