import 'package:flutter/material.dart';

import '../../core/theme/bootstrap_theme.dart';
import '../../core/utils/formatters.dart';
import '../../services/auth_service.dart';
import '../../services/export_service.dart';
import '../../services/file_storage.dart';
import '../../widgets/bs/bs_alert.dart';
import '../../widgets/bs/bs_app_bar.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/restore_backup.dart';

class BackupFilesScreen extends StatefulWidget {
  const BackupFilesScreen({super.key});

  @override
  State<BackupFilesScreen> createState() => _BackupFilesScreenState();
}

class _Listing {
  const _Listing({required this.folder, required this.files});

  final String folder;
  final List<StoredFile> files;
}

class _BackupFilesScreenState extends State<BackupFilesScreen> {
  final ExportService _export = ExportService();
  late Future<_Listing> _listing = _load();
  bool _busy = false;

  Future<_Listing> _load() async {
    final files = await _export.listBackups();
    final folder = await _export.folderPath();
    return _Listing(folder: folder, files: files);
  }

  void _reload() {
    setState(() => _listing = _load());
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore(StoredFile file) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final text = await _export.readBackup(file.name);
      if (!mounted) return;
      await confirmAndRestoreBackup(context, text, service: _export);
    } catch (e) {
      if (mounted) _snack(AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(StoredFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus cadangan?'),
        content: Text('${file.name} akan dihapus dari perangkat ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: BsColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _export.deleteBackup(file.name);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) _snack(AuthService.messageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BsAppBar(title: 'Cadangan di perangkat'),
      body: FutureBuilder<_Listing>(
        future: _listing,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!);

          final data = snap.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: BsAlert(
                  message: 'Folder: ${data.folder}',
                  variant: BsVariant.info,
                  icon: Icons.folder_outlined,
                ),
              ),
              Expanded(
                child: data.files.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Belum ada cadangan',
                        message:
                            'Buat cadangan lewat Pengaturan > Simpan '
                            'cadangan ke berkas.',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          for (final file in data.files)
                            _FileTile(
                              file: file,
                              onRestore: _busy ? null : () => _restore(file),
                              onDelete: _busy ? null : () => _delete(file),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.onRestore,
    required this.onDelete,
  });

  final StoredFile file;
  final VoidCallback? onRestore;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return BsCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      onTap: onRestore,
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: BsColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${Fmt.dateTime(file.modified)} • '
                  '${Fmt.fileSize(file.sizeBytes)}',
                  style: const TextStyle(fontSize: 12, color: BsColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus cadangan',
            icon: const Icon(Icons.delete_outline, color: BsColors.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
