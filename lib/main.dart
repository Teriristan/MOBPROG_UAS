import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/local_db.dart';
import 'data/prefs_store.dart';
import 'providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  try {
    // Membuka localStorage (web) / penyimpanan lokal (Android), lalu memuat
    // seluruh data ke memori.
    await LocalDb.instance.init(store: PrefsStore());
  } catch (e) {
    runApp(StartupErrorApp(message: '$e'));
    return;
  }

  final settings = SettingsProvider();
  await settings.load();

  runApp(LarikuApp(settings: settings));
}
