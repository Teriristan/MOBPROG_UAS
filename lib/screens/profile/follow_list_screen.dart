import 'package:flutter/material.dart';

import '../../core/theme/bootstrap_theme.dart';
import '../../data/local_db.dart';
import '../../models/app_user.dart';
import '../../services/follow_service.dart';
import '../../widgets/bs/bs_app_bar.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/user_avatar.dart';
import 'profile_screen.dart';

class FollowListScreen extends StatefulWidget {
  const FollowListScreen({
    super.key,
    required this.uid,
    required this.followers,
  });

  final String uid;
  final bool followers;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final FollowService _service = FollowService();

  late final Stream<Set<String>> _stream = widget.followers
      ? _service.watchFollowerIds(widget.uid)
      : _service.watchFollowingIds(widget.uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BsAppBar(title: widget.followers ? 'Pengikut' : 'Mengikuti'),
      body: StreamBuilder<Set<String>>(
        stream: _stream,
        builder: (context, snap) {
          final ids = snap.data;
          if (ids == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final users =
              <AppUser>[
                for (final id in ids)
                  if (LocalDb.instance.userById(id) != null)
                    LocalDb.instance.userById(id)!,
              ]..sort(
                (a, b) => a.displayName.toLowerCase().compareTo(
                  b.displayName.toLowerCase(),
                ),
              );

          if (users.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline,
              title: widget.followers
                  ? 'Belum ada pengikut'
                  : 'Belum mengikuti siapa pun',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            itemBuilder: (context, i) {
              final user = users[i];
              return BsCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileScreen(uid: user.uid),
                  ),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      name: user.displayName,
                      radius: 22,
                      uid: user.uid,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (user.bio.isNotEmpty)
                            Text(
                              user.bio,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: BsColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: BsColors.muted),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
