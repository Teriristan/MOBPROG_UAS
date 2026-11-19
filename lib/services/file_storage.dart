import '../core/app_exception.dart';

/// Satu berkas teks di folder penyimpanan aplikasi.
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

/// Tempat menyimpan berkas teks (cadangan JSON, ekspor GPX).
///
/// Dibuat sebagai antarmuka supaya kode di atasnya tidak bergantung pada
/// `dart:io` (yang tidak ada di web) dan mudah diuji dengan versi di memori.
/// Wujud sungguhan dipilih per platform oleh `file_storage_platform.dart`.
abstract interface class FileStorage {
  /// false bila platform tidak bisa menyimpan berkas (web).
  bool get isSupported;

  /// Lokasi folder penyimpanan, untuk ditampilkan kepada pengguna.
  Future<String> folderPath();

  /// Menulis [content] ke berkas [name] (menimpa bila sudah ada) dan
  /// mengembalikan lokasi lengkap berkas.
  Future<String> write(String name, String content);

  /// Membaca isi berkas [name].
  Future<String> read(String name);

  /// Daftar berkas yang namanya diawali [prefix] dan diakhiri [suffix],
  /// yang terbaru di atas.
  Future<List<StoredFile>> list({String prefix = '', String suffix = ''});

  /// Menghapus berkas [name]. Berkas yang tidak ada dibiarkan.
  Future<void> delete(String name);
}

/// Dipakai di platform tanpa akses berkas: semua operasi menolak dengan
/// pesan yang jelas.
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
