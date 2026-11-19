import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'directory_file_storage.dart';
import 'file_storage.dart';

/// Android, iOS, dan desktop: berkas disimpan di folder `Lariku` di dalam
/// folder dokumen aplikasi (path_provider).
FileStorage createPlatformFileStorage() {
  return DirectoryFileStorage(() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}${Platform.pathSeparator}Lariku');
  });
}
