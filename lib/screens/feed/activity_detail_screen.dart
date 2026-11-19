import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/bootstrap_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../models/comment.dart';
import '../../providers/auth_provider.dart';
import '../../services/activity_service.dart';
import '../../services/auth_service.dart';
import '../../services/export_service.dart';
import '../../services/social_service.dart';
import '../../widgets/bs/bs_app_bar.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/route_map.dart';
import '../../widgets/saved_file_dialog.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/user_avatar.dart';
import '../profile/profile_screen.dart';

/// Detail aktivitas: peta rute, angka, kudos, dan komentar.
class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final ActivityService _activities = ActivityService();
  final SocialService _social = SocialService();
  final ExportService _export = ExportService();
  final TextEditingController _commentC = TextEditingController();

  late final Stream<Activity?> _activityStream = _activities.watchOne(
    widget.activityId,
  );
  late final Stream<List<Comment>> _commentsStream = _social.watchComments(
    widget.activityId,
  );

  bool _sending = false;

  @override
  void dispose() {
    _commentC.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleKudos(Activity a, String me) async {
    try {
      await _social.setKudos(activityId: a.id, uid: me, give: !a.isKudosBy(me));
    } catch (e) {
      if (mounted) _snack(AuthService.messageFor(e));
    }
  }

  Future<void> _sendComment(Activity a) async {
    final text = _commentC.text.trim();
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (text.isEmpty || uid == null || _sending) return;

    setState(() => _sending = true);
    try {
      await _social.addComment(
        activityId: a.id,
        userId: uid,
        userName: auth.displayName,
        text: text,
      );
      _commentC.clear();
    } catch (e) {
      if (mounted) _snack(AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(Activity a, Comment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus komentar?'),
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
      await _social.deleteComment(activityId: a.id, commentId: c.id);
    } catch (e) {
      if (mounted) _snack(AuthService.messageFor(e));
    }
  }

  /// Menyimpan rute sebagai berkas GPX di folder aplikasi.
  Future<void> _saveGpx(Activity a) async {
    try {
      final saved = await _export.saveGpx(a);
      if (!mounted) return;
      await showSavedFileDialog(context, title: 'GPX tersimpan', file: saved);
    } catch (e) {
      if (mounted) _snack(AuthService.messageFor(e));
    }
  }

  /// Menyalin rute sebagai teks GPX (berlaku juga di web).
  Future<void> _copyGpx(Activity a) async {
    try {
      await Clipboard.setData(ClipboardData(text: _export.buildGpx(a)));
      if (mounted) _snack('GPX disalin ke papan klip.');
    } catch (e) {
      if (mounted) _snack(AuthService.messageFor(e));
    }
  }

  Future<void> _deleteActivity(Activity a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus aktivitas?'),
        content: const Text(
          'Aktivitas beserta semua komentarnya akan dihapus permanen.',
        ),
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
      await _activities.delete(a.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _snack(AuthService.messageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.select<AuthProvider, String?>((auth) => auth.user?.uid);

    return StreamBuilder<Activity?>(
      stream: _activityStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: const BsAppBar(title: 'Aktivitas'),
            body: ErrorView(error: snap.error!),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            appBar: BsAppBar(title: 'Aktivitas'),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final a = snap.data;
        if (a == null) {
          return const Scaffold(
            appBar: BsAppBar(title: 'Aktivitas'),
            body: EmptyState(
              icon: Icons.search_off,
              title: 'Aktivitas tidak ditemukan',
              message: 'Aktivitas ini mungkin sudah dihapus.',
            ),
          );
        }
        return _buildDetail(context, a, me);
      },
    );
  }

  Widget _buildDetail(BuildContext context, Activity a, String? me) {
    final isOwner = me != null && a.userId == me;
    final liked = a.isKudosBy(me);
    final canExport = a.route.length >= 2;

    return Scaffold(
      appBar: BsAppBar(
        title: 'Aktivitas',
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              tooltip: 'Menu',
              onSelected: (value) {
                switch (value) {
                  case 'gpx_file':
                    _saveGpx(a);
                  case 'gpx_copy':
                    _copyGpx(a);
                  case 'delete':
                    _deleteActivity(a);
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                if (canExport && _export.canSaveFiles)
                  const PopupMenuItem<String>(
                    value: 'gpx_file',
                    child: Text('Simpan GPX ke berkas'),
                  ),
                if (canExport)
                  const PopupMenuItem<String>(
                    value: 'gpx_copy',
                    child: Text('Salin GPX ke papan klip'),
                  ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Hapus aktivitas'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                SizedBox(
                  height: 260,
                  child: RouteMap(
                    route: a.route,
                    fitRoute: true,
                    showEndpoints: true,
                    color: a.type.color,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProfileScreen(uid: a.userId),
                          ),
                        ),
                        child: Row(
                          children: [
                            UserAvatar(name: a.userName, radius: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.userName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    Fmt.dateTime(a.startTime),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: BsColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(a.type.icon, color: a.type.color),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        a.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (a.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(a.description),
                        ),
                      const SizedBox(height: 16),
                      BsCard(
                        child: ActivityStatsRow(
                          distanceM: a.distanceM,
                          durationS: a.durationS,
                          type: a.type,
                          big: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          BsButton(
                            label: liked ? 'Kudos diberikan' : 'Beri kudos',
                            icon: liked
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            outline: !liked,
                            onPressed: me == null
                                ? null
                                : () => _toggleKudos(a, me),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${a.kudosCount} kudos',
                            style: const TextStyle(color: BsColors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Komentar (${a.commentsCount})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Comment>>(
                        stream: _commentsStream,
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return ErrorView(error: snap.error!);
                          }
                          final comments = snap.data;
                          if (comments == null) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (comments.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Belum ada komentar. Jadilah yang pertama!',
                                style: TextStyle(color: BsColors.muted),
                              ),
                            );
                          }
                          return Column(
                            children: [
                              for (final c in comments)
                                _CommentTile(
                                  comment: c,
                                  canDelete:
                                      me != null && (c.userId == me || isOwner),
                                  onDelete: () => _deleteComment(a, c),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _CommentInput(
            controller: _commentC,
            sending: _sending,
            onSend: () => _sendComment(a),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  final Comment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(name: comment.userName, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.userName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  Fmt.dateTime(comment.createdAt),
                  style: const TextStyle(fontSize: 11, color: BsColors.muted),
                ),
                const SizedBox(height: 2),
                Text(comment.text),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              tooltip: 'Hapus komentar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: BsColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                minLines: 1,
                maxLines: 3,
                maxLength: 300,
                decoration: InputDecoration(
                  hintText: 'Tulis komentar...',
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: BsColors.light,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Kirim',
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: BsColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
