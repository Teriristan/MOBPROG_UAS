import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/bootstrap_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../models/activity_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/follow_provider.dart';
import '../../services/leaderboard_service.dart';
import '../../widgets/bs/bs_app_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/user_avatar.dart';
import '../profile/profile_screen.dart';

enum _Period { week, month }

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardService _service = LeaderboardService();

  _Period _period = _Period.week;
  ActivityType? _type; // null = semua jenis
  bool _onlyFollowing = false;
  late Stream<List<Activity>> _stream = _service.watchSince(_startOf(_period));

  static DateTime _startOf(_Period period) {
    final now = DateTime.now();
    return period == _Period.week
        ? Dates.startOfWeek(now)
        : Dates.startOfMonth(now);
  }

  void _setPeriod(_Period period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      _stream = _service.watchSince(_startOf(period));
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = context.select<AuthProvider, String?>((a) => a.user?.uid);
    final following = context.watch<FollowProvider>().followingIds;

    return Scaffold(
      appBar: const BsAppBar(title: 'Peringkat'),
      body: Column(
        children: [
          _buildFilters(),
          const Divider(height: 1, color: BsColors.border),
          Expanded(
            child: StreamBuilder<List<Activity>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) return ErrorView(error: snap.error!);

                final data = snap.data;
                if (data == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final Set<String>? onlyUsers = (_onlyFollowing && me != null)
                    ? <String>{me, ...following}
                    : null;
                final entries = LeaderboardService.rank(
                  data,
                  type: _type,
                  onlyUsers: onlyUsers,
                );

                if (entries.isEmpty) {
                  return const EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: 'Belum ada data',
                    message: 'Belum ada aktivitas pada periode dan filter ini.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => _RankTile(
                    rank: i + 1,
                    entry: entries[i],
                    isMe: entries[i].userId == me,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_Period>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<_Period>(
                value: _Period.week,
                label: Text('Minggu ini'),
              ),
              ButtonSegment<_Period>(
                value: _Period.month,
                label: Text('Bulan ini'),
              ),
            ],
            selected: <_Period>{_period},
            onSelectionChanged: (s) => _setPeriod(s.first),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<bool>(value: false, label: Text('Semua pengguna')),
              ButtonSegment<bool>(value: true, label: Text('Yang saya ikuti')),
            ],
            selected: <bool>{_onlyFollowing},
            onSelectionChanged: (s) => setState(() => _onlyFollowing = s.first),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Semua jenis'),
                  selected: _type == null,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _type = null),
                ),
                for (final t in ActivityType.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      avatar: Icon(
                        t.icon,
                        size: 18,
                        color: _type == t ? Colors.white : t.color,
                      ),
                      label: Text(t.label),
                      selected: _type == t,
                      selectedColor: t.color,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: _type == t ? Colors.white : BsColors.body,
                      ),
                      onSelected: (_) => setState(() => _type = t),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  static const Color _gold = Color(0xFFFFC107);
  static const Color _silver = Color(0xFFADB5BD);
  static const Color _bronze = Color(0xFFCD7F32);

  Color? get _medal => switch (rank) {
    1 => _gold,
    2 => _silver,
    3 => _bronze,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final medal = _medal;
    final radius = BorderRadius.circular(BsRadius.md);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMe ? BsVariant.primary.subtleBg : Colors.white,
        border: Border.all(
          color: isMe ? BsVariant.primary.subtleBorder : BsColors.border,
        ),
        borderRadius: radius,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(uid: entry.userId),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: medal ?? BsColors.light,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: medal == null ? BsColors.muted : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                UserAvatar(name: entry.userName, radius: 20, uid: entry.userId),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? '${entry.userName} (Anda)' : entry.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${entry.count} aktivitas • '
                        '${Fmt.duration(entry.durationS)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: BsColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.km(entry.distanceM),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'km',
                      style: TextStyle(fontSize: 11, color: BsColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
