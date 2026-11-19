import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/bootstrap_theme.dart';
import '../core/utils/formatters.dart';
import '../models/backup_summary.dart';
import '../providers/auth_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/tracking_provider.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';

/// Memeriksa teks cadangan, meminta persetujuan pengguna, lalu memulihkannya.
/// Mengembalikan true bila data berhasil diganti.
///
/// Setelah berhasil, semua layar di atas halaman utama ditutup dan pengguna
/// kembali ke halaman masuk, karena sesi login tidak ikut dicadangkan.
Future<bool> confirmAndRestoreBackup(
  BuildContext context,
  String text, {
  ExportService? service,
}) async {
  final export = service ?? ExportService();
  final auth = context.read<AuthProvider>();
  final tracking = context.read<TrackingProvider>();
  final nav = context.read<NavProvider>();
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  void say(String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  final BackupSummary summary;
  try {
    summary = export.inspectBackup(text);
  } catch (e) {
    say(AuthService.messageFor(e));
    return false;
  }

  final created = summary.exportedAt;
  final recording = tracking.status != TrackingStatus.idle;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Pulihkan cadangan?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (created != null)
              Text(
                'Dibuat ${Fmt.dateTime(created)}',
                style: const TextStyle(color: BsColors.muted),
              ),
            Text(
              '${summary.users} akun, ${summary.activities} aktivitas, '
              '${summary.comments} komentar.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Semua akun dan aktivitas yang ada sekarang akan diganti dengan '
              'isi cadangan ini, lalu Anda perlu masuk kembali. Tindakan ini '
              'tidak bisa dibatalkan.',
            ),
            if (recording) ...[
              const SizedBox(height: 12),
              const Text('Rekaman aktivitas yang belum disimpan akan dibuang.'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Pulihkan',
            style: TextStyle(color: BsColors.danger),
          ),
        ),
      ],
    ),
  );
  if (ok != true) return false;

  try {
    await export.restoreBackup(text);
  } catch (e) {
    say(AuthService.messageFor(e));
    return false;
  }

  tracking.reset();
  nav.go(0);
  auth.syncSession();
  navigator.popUntil((route) => route.isFirst);
  say('Cadangan dipulihkan. Silakan masuk kembali.');
  return true;
}
