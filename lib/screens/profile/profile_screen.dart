import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/bootstrap_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/follow_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../services/activity_service.dart';
import '../../services/auth_service.dart';
import '../../services/follow_service.dart';
import '../../services/user_service.dart';
import '../../widgets/activity_card.dart';
import '../../widgets/bs/bs_app_bar.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/user_avatar.dart';
import '../settings/settings_screen.dart';
import 'edit_profile_screen.dart';

/// Profil seseorang: nama, bio, pengikut, total, dan daftar aktivitasnya.
///
/// [isTab] = true dipakai untuk tab "Profil" milik sendiri (ada tombol keluar).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.uid, this.isTab = false});

  final String uid;
  final bool isTab;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _users = UserService();
  final ActivityService _activities = ActivityService();
  final FollowService _follows = FollowService();

  late final Stream<AppUser?> _userStream = _users.watchUser(widget.uid);
  late final Stream<List<Activity>> _activityStream = _activities.watchByUser(
    widget.uid,
  );
  late final Stream<int> _followersStream = _follows.watchFollowersCount(
    widget.uid,
  );
  late final Stream<int> _followingStream = _follows.watchFollowingCount(
    widget.uid,
  );

  bool _busy = false;

  Future<void> _toggleFollow() async {
    if (_busy) return;
    final follow = context.read<FollowProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      await follow.toggle(widget.uid);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthService.messageFor(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    final tracking = context.read<TrackingProvider>();
    final nav = context.read<NavProvider>();
    final auth = context.read<AuthProvider>();
    final recording = tracking.status != TrackingStatus.idle;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: Text(
          recording
              ? 'Rekaman aktivitas yang belum disimpan akan dibuang.'
              : 'Anda bisa masuk kembali kapan saja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Keluar',
              style: TextStyle(color: BsColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    tracking.reset();
    nav.go(0);
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.select<AuthProvider, String?>((a) => a.user?.uid);
    final isMe = me != null && me == widget.uid;

    return Scaffold(
      appBar: BsAppBar(
        title: isMe ? 'Profil Saya' : 'Profil',
        actions: [
          if (isMe && widget.isTab)
            IconButton(
              tooltip: 'Pengaturan',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
          if (isMe && widget.isTab)
            IconButton(
              tooltip: 'Keluar',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
        ],
      ),
      body: StreamBuilder<AppUser?>(
        stream: _userStream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!);

          final user = snap.data;
          if (user == null) {
            // Profil sendiri bisa belum ada sesaat setelah mendaftar.
            if (isMe || snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Pengguna tidak ditemukan',
            );
          }
          return _buildBody(user, isMe);
        },
      ),
    );
  }

  Widget _buildBody(AppUser user, bool isMe) {
    return StreamBuilder<List<Activity>>(
      stream: _activityStream,
      builder: (context, snap) {
        final items = snap.data;
        final children = <Widget>[
          _buildHeader(context, user, isMe),
          const SizedBox(height: 12),
        ];

        if (snap.hasError) {
          children.add(ErrorView(error: snap.error!));
        } else if (items == null) {
          children.add(
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else {
          children
            ..add(_buildTotals(items))
            ..add(const SizedBox(height: 16))
            ..add(
              Text(
                'Aktivitas (${items.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
            ..add(const SizedBox(height: 8));

          if (items.isEmpty) {
            children.add(
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Belum ada aktivitas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BsColors.muted),
                ),
              ),
            );
          } else {
            for (final a in items) {
              children.add(ActivityCard(activity: a, showAuthor: false));
            }
          }
        }

        return ListView(padding: const EdgeInsets.all(12), children: children);
      },
    );
  }

  Widget _buildHeader(BuildContext context, AppUser user, bool isMe) {
    final joined = user.createdAt;

    return BsCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          UserAvatar(name: user.displayName, radius: 40),
          const SizedBox(height: 12),
          Text(
            user.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          if (user.bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(user.bio, textAlign: TextAlign.center),
            ),
          if (joined != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Bergabung ${Fmt.date(joined)}',
                style: const TextStyle(fontSize: 12, color: BsColors.muted),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CountStat(label: 'Pengikut', stream: _followersStream),
              const SizedBox(width: 40),
              _CountStat(label: 'Mengikuti', stream: _followingStream),
            ],
          ),
          const SizedBox(height: 14),
          if (isMe)
            BsButton(
              label: 'Ubah profil',
              icon: Icons.edit_outlined,
              outline: true,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EditProfileScreen(user: user),
                ),
              ),
            )
          else
            _FollowButton(
              uid: widget.uid,
              busy: _busy,
              onPressed: _toggleFollow,
            ),
        ],
      ),
    );
  }

  Widget _buildTotals(List<Activity> items) {
    var distance = 0.0;
    var seconds = 0;
    for (final a in items) {
      distance += a.distanceM;
      seconds += a.durationS;
    }

    return BsCard(
      child: Row(
        children: [
          Expanded(
            child: StatTile(label: 'Aktivitas', value: '${items.length}'),
          ),
          Expanded(
            child: StatTile(
              label: 'Jarak',
              value: Fmt.km(distance),
              unit: 'km',
            ),
          ),
          Expanded(
            child: StatTile(label: 'Waktu', value: Fmt.duration(seconds)),
          ),
        ],
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.uid,
    required this.busy,
    required this.onPressed,
  });

  final String uid;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final following = context.select<FollowProvider, bool>(
      (f) => f.isFollowing(uid),
    );

    return BsButton(
      label: following ? 'Mengikuti' : 'Ikuti',
      icon: following ? Icons.check : Icons.person_add_alt_1,
      outline: following,
      loading: busy,
      onPressed: onPressed,
    );
  }
}

class _CountStat extends StatelessWidget {
  const _CountStat({required this.label, required this.stream});

  final String label;
  final Stream<int> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snap) => Column(
        children: [
          Text(
            '${snap.data ?? 0}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: BsColors.muted),
          ),
        ],
      ),
    );
  }
}
