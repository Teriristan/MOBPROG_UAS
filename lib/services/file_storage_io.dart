import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'directory_file_storage.dart';
import 'file_storage.dart';

FileStorage createPlatformFileStorage() {
  return DirectoryFileStorage(() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}${Platform.pathSeparator}Lariku');
  });
}
