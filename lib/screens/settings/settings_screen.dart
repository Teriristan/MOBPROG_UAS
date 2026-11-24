import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme/bootstrap_theme.dart';
import '../../models/activity_type.dart';
import '../../models/app_settings.dart';
import '../../providers/settings_provider.dart';
import '../../services/auth_service.dart';
import '../../services/export_service.dart';
import '../../widgets/bs/bs_app_bar.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/reset_data.dart';
import '../../widgets/restore_backup.dart';
import '../../widgets/saved_file_dialog.dart';
import 'backup_files_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ExportService _export = ExportService();
  bool _busy = false;

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(Future<String?> change) async {
    final error = await change;
    if (error != null && mounted) _snack(error);
  }

  Future<void> _guarded(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _snack(AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveBackupFile() {
    return _guarded(() async {
      final saved = await _export.saveBackup();
      if (!mounted) return;
      await showSavedFileDialog(
        context,
        title: 'Cadangan tersimpan',
        file: saved,
      );
    });
  }

  void _openBackupFiles() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BackupFilesScreen()));
  }

  Future<void> _copyBackup() {
    return _guarded(() async {
      await Clipboard.setData(ClipboardData(text: _export.buildBackup()));
      if (mounted) {
        _snack(
          'Cadangan disalin ke papan klip. Tempel di catatan atau pesan '
          'untuk menyimpannya.',
        );
      }
    });
  }

  Future<void> _restoreFromClipboard() {
    return _guarded(() async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (!mounted) return;
      if (text.isEmpty) {
        _snack('Papan klip kosong. Salin dulu teks cadangan Lariku.');
        return;
      }
      await confirmAndRestoreBackup(context, text, service: _export);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final goal = settings.weeklyGoalKm;
    final canFiles = _export.canSaveFiles;
    const noFiles = 'Tidak tersedia di versi web. Pakai papan klip.';

    return Scaffold(
      appBar: const BsAppBar(title: 'Pengaturan'),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _SectionTitle('Perekaman'),
          BsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jenis aktivitas bawaan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Terpilih saat layar Rekam dibuka.',
                  style: TextStyle(fontSize: 12, color: BsColors.muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final type in ActivityType.values)
                      ChoiceChip(
                        avatar: Icon(
                          type.icon,
                          size: 18,
                          color: settings.defaultType == type
                              ? Colors.white
                              : type.color,
                        ),
                        label: Text(type.label),
                        selected: settings.defaultType == type,
                        selectedColor: type.color,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: settings.defaultType == type
                              ? Colors.white
                              : BsColors.body,
                        ),
                        onSelected: (_) => _save(settings.setDefaultType(type)),
                      ),
                  ],
                ),
                const Divider(height: 28, color: BsColors.border),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Mode simulasi bawaan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Rute dibuat otomatis tanpa GPS, untuk uji coba di '
                    'komputer atau saat tidak bergerak.',
                    style: TextStyle(fontSize: 12, color: BsColors.muted),
                  ),
                  value: settings.simulateByDefault,
                  onChanged: (value) =>
                      _save(settings.setSimulateByDefault(value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Target mingguan'),
          BsCard(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton.outlined(
                      tooltip: 'Kurangi ${AppSettings.weeklyGoalStepKm} km',
                      onPressed: goal > AppSettings.minWeeklyGoalKm
                          ? () => _save(
                              settings.setWeeklyGoalKm(
                                goal - AppSettings.weeklyGoalStepKm,
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '$goal km',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'per minggu',
                            style: TextStyle(
                              fontSize: 12,
                              color: BsColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Tambah ${AppSettings.weeklyGoalStepKm} km',
                      onPressed: goal < AppSettings.maxWeeklyGoalKm
                          ? () => _save(
                              settings.setWeeklyGoalKm(
                                goal + AppSettings.weeklyGoalStepKm,
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kemajuan minggu ini tampil di tab Statistik.',
                  style: TextStyle(fontSize: 12, color: BsColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Data'),
          BsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.save_alt,
                  title: 'Simpan cadangan ke berkas',
                  subtitle: canFiles
                      ? 'Disimpan di folder aplikasi pada perangkat ini.'
                      : noFiles,
                  onTap: canFiles && !_busy ? _saveBackupFile : null,
                ),
                const Divider(height: 1, color: BsColors.border),
                _ActionTile(
                  icon: Icons.folder_open,
                  title: 'Pulihkan dari berkas',
                  subtitle: canFiles
                      ? 'Pilih salah satu cadangan yang tersimpan.'
                      : noFiles,
                  onTap: canFiles && !_busy ? _openBackupFiles : null,
                ),
                const Divider(height: 1, color: BsColors.border),
                _ActionTile(
                  icon: Icons.content_copy,
                  title: 'Salin cadangan ke papan klip',
                  subtitle: 'Tempel di catatan atau pesan untuk menyimpannya.',
                  onTap: _busy ? null : _copyBackup,
                ),
                const Divider(height: 1, color: BsColors.border),
                _ActionTile(
                  icon: Icons.content_paste,
                  title: 'Pulihkan dari papan klip',
                  subtitle: 'Pakai teks cadangan yang baru Anda salin.',
                  onTap: _busy ? null : _restoreFromClipboard,
                ),
                const Divider(height: 1, color: BsColors.border),
                _ActionTile(
                  icon: Icons.restart_alt,
                  title: 'Atur ulang data lokal',
                  subtitle:
                      'Hapus semua akun dan aktivitas, lalu muat data contoh.',
                  danger: true,
                  onTap: _busy ? null : () => confirmAndResetLocalData(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BsButton(
            label: 'Kembalikan pengaturan bawaan',
            icon: Icons.settings_backup_restore,
            variant: BsVariant.secondary,
            outline: true,
            block: true,
            onPressed: () => _save(settings.restoreDefaults()),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              '${AppConstants.appName} • UAS Mobile Programming',
              style: TextStyle(fontSize: 12, color: BsColors.muted),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? BsColors.danger : BsColors.primary;

    return ListTile(
      enabled: onTap != null,
      leading: Icon(icon, color: onTap == null ? BsColors.muted : color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: danger && onTap != null ? BsColors.danger : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: BsColors.muted),
      ),
      trailing: const Icon(Icons.chevron_right, color: BsColors.muted),
      onTap: onTap,
    );
  }
}
