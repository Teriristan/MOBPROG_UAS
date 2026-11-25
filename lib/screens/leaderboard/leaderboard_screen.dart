import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

enum _Metric { distance, time, count }

const List<String> _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

double _value(LeaderboardEntry e, _Metric m) => switch (m){
      _Metric.distance => e.distanceM.toDouble(),
      _Metric.time => e.durationS.toDouble(),
      _Metric.count => e.count.toDouble(),
    };

String _primary(LeaderboardEntry e, _Metric m) => switch (m){
      _Metric.distance => Fmt.km(e.distanceM),
      _Metric.time => Fmt.duration(e.durationS),
      _Metric.count => '${e.count}',
    };

String _unit(_Metric m) => switch (m) {
      _Metric.distance => 'km',
      _Metric.time => 'waktu',
      _Metric.count => 'aktivitas',
    };

String _secondary(LeaderboardEntry e, _Metric m) => switch (m) {
      _Metric.distance => '${e.count} aktivitas • ${Fmt.duration(e.durationS)}',
      _Metric.time => '${e.count} aktivitas • ${Fmt.km(e.distanceM)} km',
      _Metric.count => '${Fmt.km(e.distanceM)} km • ${Fmt.duration(e.durationS)}',
    };

String _shortLabel(LeaderboardEntry e, _Metric m) => switch (m) {
      _Metric.distance => '${Fmt.km(e.distanceM)} km',
      _Metric.time => Fmt.duration(e.durationS),
      _Metric.count => '${e.count} akt.',
    };

String _gapText(_Metric m, LeaderboardEntry ahead, LeaderboardEntry me) =>
    switch (m) {
      _Metric.distance => '${Fmt.km(ahead.distanceM - me.distanceM)} km',
      _Metric.time => Fmt.duration(ahead.durationS - me.durationS),
      _Metric.count => '${ahead.count - me.count} aktivitas',
    };

List<Color>? _medalColors(int rank) => switch (rank) {
      1 => const [Color(0xFFFFD54F), Color(0xFFFFC107)],
      2 => const [Color(0xFFCED4DA), Color(0xFFADB5BD)],
      3 => const [Color(0xFFE0A15E), Color(0xFFCD7F32)],
      _ => null,
    };

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardService _service = LeaderboardService();
  final TextEditingController _searchCtrl = TextEditingController();

  _Period _period = _Period.week;
  ActivityType? _type; // null = semua jenis
  bool _onlyFollowing = false;
  _Metric _metric = _Metric.distance;
  bool _podium = true;
  String _query = '';
  late Stream<List<Activity>> _stream = _service.watchSince(_startOf(_period));

  static DateTime _startOf(_Period period) {
    final now = DateTime.now();
    return period == _Period.week
        ? Dates.startOfWeek(now)
        : Dates.startOfMonth(now);
  }

  DateTime get _endOfPeriod {
    final s = _startOf(_period);
    return _period == _Period.week
        ? s.add(const Duration(days: 7))
        : DateTime(s.year, s.month + 1, 1);
  }

  String get _rangeText {
    final s = _startOf(_period);
    final e = _endOfPeriod.subtract(const Duration(days: 1));
    return '${s.day} ${_bulan[s.month - 1]} – ${e.day} ${_bulan[e.month - 1]}';
  }

  String get _remainingText {
    final d = _endOfPeriod.difference(DateTime.now());
    if (d.isNegative) return 'Periode berakhir';
    final days = d.inDays;
    final hours = d.inHours % 24;
    return days > 0
        ? 'Berakhir dalam $days hari $hours jam'
        : 'Berakhir dalam $hours jam';
  }

  String get _periodLabel =>
      _period == _Period.week ? 'Minggu ini' : 'Bulan ini';

  void _setPeriod(_Period period) {
    if (period == _period) return;
    HapticFeedback.selectionClick();
    setState(() {
      _period = period;
      _stream = _service.watchSince(_startOf(period));
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.select<AuthProvider, String?>((a) => a.user?.uid);
    final following = context.watch<FollowProvider>().followingIds;

    return Scaffold(
      appBar: const BsAppBar(title: 'Peringkat'),
      body: StreamBuilder<List<Activity>>(
        stream: _stream,
        builder: (context, snap) => _buildBody(snap, me, following),
      ),
    );
  }

  Widget _buildBody(
    AsyncSnapshot<List<Activity>> snap,
    String? me,
    Iterable<String> following,
  ) {
    final data = snap.data;
    final hasError = snap.hasError;
    final loading = data == null && !hasError;

    var ranked = <LeaderboardEntry>[];
    if (data != null) {
      final Set<String>? onlyUsers = (_onlyFollowing && me != null)
          ? <String>{me, ...following}
          : null;
      ranked = List<LeaderboardEntry>.of(
        LeaderboardService.rank(data, type: _type, onlyUsers: onlyUsers),
      );
      ranked.sort((a, b) {
        final c = _value(b, _metric).compareTo(_value(a, _metric));
        return c != 0 ? c : b.distanceM.compareTo(a.distanceM);
      });
    }

    final q = _query.trim().toLowerCase();
    final searching = q.isNotEmpty;
    final showPodium = _podium && !searching && ranked.length >= 3;
    final startIndex = showPodium ? 3 : 0;
    final listIdx = <int>[
      for (var i = startIndex; i < ranked.length; i++)
        if (!searching || ranked[i].userName.toLowerCase().contains(q)) i,
    ];

    final sig =
        '${_period.name}-$_onlyFollowing-${_type?.name}-${_metric.name}';
    final leaderValue = ranked.isEmpty ? 0.0 : _value(ranked.first, _metric);
    final meIndex =
        me == null ? -1 : ranked.indexWhere((e) => e.userId == me);
    final totalMeters =
        ranked.fold<double>(0, (s, e) => s + e.distanceM.toDouble());

    final scroll = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Header(
            remaining: _remainingText,
            range: _rangeText,
            loading: loading,
            athleteCount: ranked.length,
            totalMeters: totalMeters,
            podium: showPodium ? ranked.take(3).toList() : const [],
            metric: _metric,
            sig: sig,
            meId: me,
            onTap: (i) => _showDetail(ranked, i),
          ),
        ),
        SliverToBoxAdapter(child: _buildFilters()),
        if (hasError)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorView(error: snap.error!),
          )
        else if (loading)
          const SliverToBoxAdapter(child: _SkeletonList())
        else if (ranked.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'Belum ada data',
              message: 'Belum ada aktivitas pada periode dan filter ini.',
            ),
          )
        else if (listIdx.isEmpty && !showPodium)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off,
              title: 'Tidak ditemukan',
              message: 'Tidak ada atlet bernama "$_query".',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            sliver: SliverList.builder(
              itemCount: listIdx.length,
              itemBuilder: (context, n) {
                final i = listIdx[n];
                final e = ranked[i];
                return _RankTile(
                  key: ValueKey('$sig-${e.userId}-$searching'),
                  rank: i + 1,
                  entry: e,
                  metric: _metric,
                  leaderValue: leaderValue,
                  isMe: e.userId == me,
                  index: n,
                  onTap: () => _showDetail(ranked, i),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );

    return Column(
      children: [
        Expanded(child: scroll),
        if (!loading && !hasError)
          _MyRankBar(
            ranked: ranked,
            meIndex: meIndex,
            metric: _metric,
            onTap: meIndex < 0 ? null : () => _showDetail(ranked, meIndex),
          ),
      ],
    );
  }

  void _showDetail(List<LeaderboardEntry> ranked, int index) {
    HapticFeedback.lightImpact();
    final e = ranked[index];
    final isMe = context.read<AuthProvider>().user?.uid == e.userId;
    final navigator = Navigator.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => _DetailSheet(
        entry: e,
        rank: index + 1,
        leader: ranked.first,
        periodLabel: _periodLabel,
        isMe: isMe,
        onOpenProfile: () {
          Navigator.pop(sheetCtx);
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(uid: e.userId),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        Container(
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
                    icon: Icon(Icons.date_range, size: 18),
                  ),
                  ButtonSegment<_Period>(
                    value: _Period.month,
                    label: Text('Bulan ini'),
                    icon: Icon(Icons.calendar_month, size: 18),
                  ),
                ],
                selected: <_Period>{_period},
                onSelectionChanged: (s) => _setPeriod(s.first),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Semua pengguna'),
                    icon: Icon(Icons.public, size: 18),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Yang saya ikuti'),
                    icon: Icon(Icons.people_alt_outlined, size: 18),
                  ),
                ],
                selected: <bool>{_onlyFollowing},
                onSelectionChanged: (s) {
                  HapticFeedback.selectionClick();
                  setState(() => _onlyFollowing = s.first);
                },
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.apps_rounded, size: 18),
                      label: const Text('Semua jenis'),
                      selected: _type == null,
                      showCheckmark: false,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _type = null);
                      },
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
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _type = t);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text(
                        'Urutkan:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BsColors.muted,
                        ),
                      ),
                    ),
                    _metricChip('Jarak', _Metric.distance),
                    _metricChip('Waktu', _Metric.time),
                    _metricChip('Aktivitas', _Metric.count),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Cari atlet…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(BsRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: _podium ? 'Tampilan daftar' : 'Tampilan podium',
                    icon: Icon(
                      _podium ? Icons.view_list_rounded : Icons.emoji_events,
                    ),
                    onPressed: () => setState(() => _podium = !_podium),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: BsColors.border),
      ],
    );
  }

  Widget _metricChip(String label, _Metric m) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: _metric == m,
        showCheckmark: false,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() => _metric = m);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.remaining,
    required this.range,
    required this.loading,
    required this.athleteCount,
    required this.totalMeters,
    required this.podium,
    required this.metric,
    required this.sig,
    required this.meId,
    required this.onTap,
  });

  final String remaining;
  final String range;
  final bool loading;
  final int athleteCount;
  final double totalMeters;
  final List<LeaderboardEntry> podium; // kosong, atau 3 teratas
  final _Metric metric;
  final String sig;
  final String? meId;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final dark = Color.lerp(primary, Colors.black, 0.35)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primary, dark],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  remaining,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              Text(
                range,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              loading
                  ? 'Memuat peringkat…'
                  : '$athleteCount atlet • ${Fmt.km(totalMeters)} km total',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          if (podium.length == 3) ...[
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _spot(1, 78)),
                Expanded(child: _spot(0, 108)),
                Expanded(child: _spot(2, 58)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _spot(int index, double height) => _PodiumSpot(
        key: ValueKey('$sig-${podium[index].userId}'),
        entry: podium[index],
        rank: index + 1,
        metric: metric,
        height: height,
        isMe: podium[index].userId == meId,
        onTap: () => onTap(index),
      );
}

class _PodiumSpot extends StatelessWidget {
  const _PodiumSpot({
    super.key,
    required this.entry,
    required this.rank,
    required this.metric,
    required this.height,
    required this.isMe,
    required this.onTap,
  });

  final LeaderboardEntry entry;
  final int rank;
  final _Metric metric;
  final double height;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final medal = _medalColors(rank)!;
    final first = rank == 1;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (first)
            const Icon(
              Icons.workspace_premium,
              color: Color(0xFFFFD54F),
              size: 28,
            ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: medal),
            ),
            child: UserAvatar(
              name: entry.userName,
              radius: first ? 32 : 26,
              uid: entry.userId,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              entry.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            _shortLabel(entry, metric),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (isMe)
            const Text(
              'Anda',
              style: TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: height),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, h, _) => Container(
              height: h,
              margin: const EdgeInsets.only(top: 8, left: 6, right: 6),
              padding: const EdgeInsets.only(top: 8),
              alignment: Alignment.topCenter,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [medal[0].withAlpha(240), medal[1].withAlpha(190)],
                ),
              ),
              child: h > 30
                  ? Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge(this.rank);
  final int rank;

  @override
  Widget build(BuildContext context) {
    final medal = _medalColors(rank);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: medal == null ? null : LinearGradient(colors: medal),
        color: medal == null ? BsColors.light : null,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: medal == null ? BsColors.muted : Colors.white,
        ),
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({
    super.key,
    required this.rank,
    required this.entry,
    required this.metric,
    required this.leaderValue,
    required this.isMe,
    required this.index,
    required this.onTap,
  });

  final int rank;
  final LeaderboardEntry entry;
  final _Metric metric;
  final double leaderValue;
  final bool isMe;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(BsRadius.md);
    final frac = leaderValue <= 0
        ? 0.0
        : (_value(entry, metric) / leaderValue).clamp(0.0, 1.0);
    final barColor = Theme.of(context).colorScheme.primary;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index.clamp(0, 8) * 70),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
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
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RankBadge(rank),
                      const SizedBox(width: 10),
                      UserAvatar(
                        name: entry.userName,
                        radius: 20,
                        uid: entry.userId,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? '${entry.userName} (Anda)' : entry.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _secondary(entry, metric),
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
                            _primary(entry, metric),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _unit(metric),
                            style: const TextStyle(
                              fontSize: 11,
                              color: BsColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: frac),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 5,
                        color: barColor,
                        backgroundColor: BsColors.light,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MyRankBar extends StatelessWidget {
  const _MyRankBar({
    required this.ranked,
    required this.meIndex,
    required this.metric,
    required this.onTap,
  });

  final List<LeaderboardEntry> ranked;
  final int meIndex;
  final _Metric metric;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    String title;
    String message;

    if (meIndex < 0) {
      title = 'Posisi Anda';
      message = 'Belum ada aktivitas Anda pada filter ini. Ayo rekam!';
    } else if (meIndex == 0) {
      title = 'Anda di puncak!';
      if (ranked.length > 1) {
        final other = ranked[1];
        final diff = _value(ranked[0], metric) - _value(other, metric);
        message = diff <= 0
            ? 'Imbang dengan ${other.userName}'
            : 'Unggul ${_gapText(metric, ranked[0], other)} dari ${other.userName}';
      } else {
        message = 'Belum ada pesaing, pertahankan!';
      }
    } else {
      final me = ranked[meIndex];
      final ahead = ranked[meIndex - 1];
      final diff = _value(ahead, metric) - _value(me, metric);
      title = 'Posisi Anda: #${meIndex + 1}';
      message = diff <= 0
          ? 'Tambah sedikit lagi untuk menyalip ${ahead.userName}'
          : 'Butuh ${_gapText(metric, ahead, me)} lagi untuk menyalip '
              '${ahead.userName} (#$meIndex)';
    }

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black54,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              meIndex < 0
                  ? Icon(
                      Icons.directions_run,
                      size: 30,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : _RankBadge(meIndex + 1),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: BsColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (meIndex >= 0)
                const Icon(Icons.expand_less, color: BsColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({
    required this.entry,
    required this.rank,
    required this.leader,
    required this.periodLabel,
    required this.isMe,
    required this.onOpenProfile,
  });

  final LeaderboardEntry entry;
  final int rank;
  final LeaderboardEntry leader;
  final String periodLabel;
  final bool isMe;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final speed = entry.durationS == 0
        ? 0.0
        : (entry.distanceM / 1000) / (entry.durationS / 3600);
    final speedText = speed.toStringAsFixed(1).replaceAll('.', ',');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(name: entry.userName, radius: 36, uid: entry.userId),
          const SizedBox(height: 10),
          Text(
            isMe ? '${entry.userName} (Anda)' : entry.userName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'Peringkat #$rank • $periodLabel',
            style: const TextStyle(color: BsColors.muted),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _stat(Fmt.km(entry.distanceM), 'Jarak (km)'),
              const SizedBox(width: 10),
              _stat(Fmt.duration(entry.durationS), 'Waktu'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _stat('${entry.count}', 'Aktivitas'),
              const SizedBox(width: 10),
              _stat(speedText, 'Rata-rata (km/jam)'),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BsColors.light,
              borderRadius: BorderRadius.circular(BsRadius.md),
            ),
            child: Text(
              rank == 1
                  ? 'Pemimpin periode ini 🏆'
                  : 'Selisih dengan #1 (${leader.userName}): '
                      '${Fmt.km(leader.distanceM - entry.distanceM)} km',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenProfile,
              icon: const Icon(Icons.person_outline),
              label: const Text('Lihat profil'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: BsColors.light,
          borderRadius: BorderRadius.circular(BsRadius.md),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: BsColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.4, end: 1).animate(_ctrl),
        child: Column(
          children: List.generate(
            5,
            (_) => Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: BsColors.light,
                borderRadius: BorderRadius.circular(BsRadius.md),
              ),
            ),
          ),
        ),
      ),
    );
  }
}