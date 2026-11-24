import '../core/app_exception.dart';

class StoredFile {
  const StoredFile({
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });

  final String name;
  final int sizeBytes;
  final DateTime modified;
}

abstract interface class FileStorage {
  bool get isSupported;
  Future<String> folderPath();
  Future<String> write(String name, String content);
  Future<String> read(String name);
  Future<List<StoredFile>> list({String prefix = '', String suffix = ''});
  Future<void> delete(String name);
}

class UnsupportedFileStorage implements FileStorage {
  const UnsupportedFileStorage();

  static const String message =
      'Penyimpanan berkas belum tersedia di versi web. Gunakan menu salin '
      'ke papan klip sebagai gantinya.';

  @override
  bool get isSupported => false;

  @override
  Future<String> folderPath() =>
      Future<String>.error(const AppException(message));

  @override
  Future<String> write(String name, String content) =>
      Future<String>.error(const AppException(message));

  @override
  Future<String> read(String name) =>
      Future<String>.error(const AppException(message));

  @override
  Future<List<StoredFile>> list({String prefix = '', String suffix = ''}) =>
      Future<List<StoredFile>>.error(const AppException(message));

  @override
  Future<void> delete(String name) =>
      Future<void>.error(const AppException(message));
}
