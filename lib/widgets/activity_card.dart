import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/bootstrap_theme.dart';
import '../core/utils/formatters.dart';
import '../models/activity.dart';
import '../providers/auth_provider.dart';
import '../screens/feed/activity_detail_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../services/auth_service.dart';
import '../services/social_service.dart';
import 'bs/bs_card.dart';
import 'route_sketch.dart';
import 'stat_tile.dart';
import 'user_avatar.dart';

/// Kartu aktivitas di feed dan profil: pembuat, judul, angka utama,
/// sketsa rute, serta tombol kudos dan komentar.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.showAuthor = true,
  });

  final Activity activity;

  /// false → nama pembuat disembunyikan (di halaman profil orangnya sendiri).
  final bool showAuthor;

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActivityDetailScreen(activityId: activity.id),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(uid: activity.userId),
      ),
    );
  }

  Future<void> _toggleKudos(BuildContext context, String me, bool liked) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SocialService().setKudos(
        activityId: activity.id,
        uid: me,
        give: !liked,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthService.messageFor(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final me = context.select<AuthProvider, String?>((auth) => auth.user?.uid);
    final liked = a.isKudosBy(me);

    return BsCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      onTap: () => _openDetail(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showAuthor) ...[
                GestureDetector(
                  onTap: () => _openProfile(context),
                  child: UserAvatar(name: a.userName, radius: 20, uid: a.userId),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showAuthor)
                      Text(
                        a.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
          const SizedBox(height: 10),
          Text(
            a.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          if (a.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                a.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: BsColors.muted),
              ),
            ),
          const SizedBox(height: 12),
          ActivityStatsRow(
            distanceM: a.distanceM,
            durationS: a.durationS,
            type: a.type,
          ),
          const SizedBox(height: 12),
          RouteSketch(route: a.route, color: a.type.color),
          const SizedBox(height: 8),
          Row(
            children: [
              _ActionButton(
                icon: liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                label: a.kudosCount == 0 ? 'Kudos' : '${a.kudosCount} Kudos',
                active: liked,
                onTap: () {
                  if (me != null) _toggleKudos(context, me, liked);
                },
              ),
              const SizedBox(width: 4),
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                label: a.commentsCount == 0
                    ? 'Komentar'
                    : '${a.commentsCount} Komentar',
                onTap: () => _openDetail(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? BsColors.primary : BsColors.muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BsRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}