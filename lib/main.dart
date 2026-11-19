import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/local_db.dart';
import 'data/prefs_store.dart';
import 'providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Format tanggal berbahasa Indonesia (dipakai oleh Fmt di formatters.dart).
  await initializeDateFormatting('id_ID');

  try {
    // Membuka localStorage (web) / penyimpanan lokal (Android), lalu memuat
    // seluruh data ke memori.
    await LocalDb.instance.init(store: PrefsStore());
  } catch (e) {
    runApp(StartupErrorApp(message: '$e'));
    return;
  }

  // Pengaturan (SharedPreferences). Bila gagal dibaca, nilai bawaan dipakai
  // supaya aplikasi tetap bisa dibuka.
  final settings = SettingsProvider();
  await settings.load();

  runApp(LarikuApp(settings: settings));
}
