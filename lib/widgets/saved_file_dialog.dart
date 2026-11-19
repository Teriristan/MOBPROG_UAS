import 'package:flutter/material.dart';

import '../core/theme/bootstrap_theme.dart';
import '../services/export_service.dart';

/// Memberi tahu pengguna nama dan lokasi berkas yang baru disimpan.
Future<void> showSavedFileDialog(
  BuildContext context, {
  required String title,
  required SavedFile file,
}) {
  const label = TextStyle(fontSize: 12, color: BsColors.muted);

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nama berkas', style: label),
          SelectableText(
            file.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text('Lokasi', style: label),
          SelectableText(file.path),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
}
