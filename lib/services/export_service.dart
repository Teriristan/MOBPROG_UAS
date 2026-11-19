import '../core/app_exception.dart';
import '../core/utils/gpx_builder.dart';
import '../data/local_db.dart';
import '../models/activity.dart';
import '../models/backup_summary.dart';
import 'file_storage.dart';
import 'file_storage_platform.dart';

/// Berkas yang baru disimpan: nama dan lokasi lengkapnya.
class SavedFile {
  const SavedFile({required this.name, required this.path});

  final String name;
  final String path;
}

/// Cadangan data (JSON) dan ekspor rute (GPX).
///
/// Teks cadangan/GPX dibuat di sini, lalu bisa disimpan sebagai berkas di
/// folder aplikasi ([FileStorage]) atau disalin ke papan klip oleh layar.
class ExportService {
  ExportService({LocalDb? db, FileStorage? storage, DateTime Function()? now})
    : _db = db ?? LocalDb.instance,
      _storage = storage ?? createPlatformFileStorage(),
      _now = now ?? DateTime.now;

  final LocalDb _db;
  final FileStorage _storage;
  final DateTime Function() _now;

  static const String backupPrefix = 'lariku_cadangan_';
  static const String backupSuffix = '.json';

  /// false di web: berkas tidak bisa disimpan, hanya bisa disalin.
  bool get canSaveFiles => _storage.isSupported;

  /// Folder tempat berkas disimpan.
  Future<String> folderPath() => _storage.folderPath();

  // ---- Cadangan ----------------------------------------------------------

  /// Seluruh data sebagai teks JSON.
  String buildBackup() => _db.exportJson();

  /// `lariku_cadangan_20261110_184400.json`
  String backupFileName() {
    return '$backupPrefix${_stamp(_now(), withSeconds: true)}$backupSuffix';
  }

  Future<SavedFile> saveBackup() async {
    final name = backupFileName();
    final path = await _storage.write(name, buildBackup());
    return SavedFile(name: name, path: path);
  }

  /// Cadangan yang ada di folder aplikasi, yang terbaru di atas.
  Future<List<StoredFile>> listBackups() {
    return _storage.list(prefix: backupPrefix, suffix: backupSuffix);
  }

  Future<String> readBackup(String name) async {
    _requireBackupName(name);
    return _storage.read(name);
  }

  Future<void> deleteBackup(String name) async {
    _requireBackupName(name);
    await _storage.delete(name);
  }

  /// Memeriksa isi cadangan tanpa mengubah data. Melempar [AppException]
  /// bila cadangan tidak valid.
  BackupSummary inspectBackup(String text) => LocalDb.inspectBackup(text);

  /// Mengganti semua data dengan isi cadangan, lalu keluar dari akun.
  Future<BackupSummary> restoreBackup(String text) => _db.importJson(text);

  void _requireBackupName(String name) {
    if (!name.startsWith(backupPrefix) || !name.endsWith(backupSuffix)) {
      throw const AppException('Itu bukan berkas cadangan Lariku.');
    }
  }

  // ---- GPX ---------------------------------------------------------------

  /// Rute [activity] sebagai teks GPX.
  String buildGpx(Activity activity) => GpxBuilder.build(activity);

  /// `lariku_run_20261103_0630.gpx`
  String gpxFileName(Activity activity) {
    return 'lariku_${activity.type.name}_${_stamp(activity.startTime)}.gpx';
  }

  Future<SavedFile> saveGpx(Activity activity) async {
    final text = buildGpx(activity);
    final name = gpxFileName(activity);
    final path = await _storage.write(name, text);
    return SavedFile(name: name, path: path);
  }

  // ---- Bantuan -----------------------------------------------------------

  static String _stamp(DateTime d, {bool withSeconds = false}) {
    String two(int n) => n.toString().padLeft(2, '0');
    final date =
        '${d.year.toString().padLeft(4, '0')}${two(d.month)}${two(d.day)}';
    final time =
        '${two(d.hour)}${two(d.minute)}${withSeconds ? two(d.second) : ''}';
    return '${date}_$time';
  }
}
