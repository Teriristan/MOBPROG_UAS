import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/bootstrap_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/nav_provider.dart';
import '../providers/tracking_provider.dart';
import '../services/auth_service.dart';

/// Menampilkan dialog konfirmasi, lalu menghapus semua data lokal (akun,
/// aktivitas, kudos, komentar, pengikut) dan memuat ulang data contoh.
/// Setelah itu pengguna kembali ke halaman masuk.
Future<void> confirmAndResetLocalData(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final tracking = context.read<TrackingProvider>();
  final nav = context.read<NavProvider>();
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Atur ulang data lokal?'),
      content: const Text(
        'Semua akun dan aktivitas yang tersimpan di perangkat ini akan '
        'dihapus, lalu diganti dengan data contoh. Pengaturan aplikasi tidak '
        'ikut dihapus. Tindakan ini tidak bisa dibatalkan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Atur ulang',
            style: TextStyle(color: BsColors.danger),
          ),
        ),
      ],
    ),
  );
  if (ok != true) return;

  tracking.reset();
  nav.go(0);
  // Layar yang dibuka di atas halaman utama (misalnya Pengaturan) ditutup,
  // karena setelah ini pengguna kembali ke halaman masuk.
  navigator.popUntil((route) => route.isFirst);
  try {
    await auth.resetLocalData();
    messenger.showSnackBar(
      const SnackBar(content: Text('Data lokal sudah diatur ulang.')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(AuthService.messageFor(e))));
  }
}
