import 'file_storage.dart';

/// Web: tidak ada akses ke sistem berkas.
FileStorage createPlatformFileStorage() => const UnsupportedFileStorage();
