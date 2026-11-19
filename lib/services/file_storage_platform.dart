// Memilih penyimpanan berkas sesuai platform:
//  * ada dart:io (Android, iOS, desktop) -> file_storage_io.dart
//  * tidak ada (web)                     -> file_storage_stub.dart
// Keduanya menyediakan fungsi createPlatformFileStorage().
export 'file_storage_stub.dart' if (dart.library.io) 'file_storage_io.dart';
