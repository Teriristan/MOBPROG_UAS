import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/bootstrap_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../models/activity_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/activity_service.dart';
import '../../services/stats_service.dart';
import '../../widgets/bs/bs_app_bar.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/weekly_bar_chart.dart';
import '../feed/activity_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../../models/stats_period.dart';
import '../../widgets/period_filter_bar.dart';
import '../../widgets/type_filter_chips.dart';
import '../../services/stats_insights.dart';
import '../../widgets/personal_records_card.dart';
import '../../widgets/streak_card.dart';

// Statistik pribadi: ringkasan minggu ini, grafik 8 minggu, total, dan riwayat seluruh aktivitas.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final ActivityService _service = ActivityService();
  String? _uid;
  Stream<List<Activity>>? _stream;
  StatsPeriod _period = StatsPeriod.all;
  ActivityType?_type;

  @override
  Widget build(BuildContext context) {
    final uid = context.select<AuthProvider, String?>((a) => a.user?.uid);
    final goalKm = context.select<SettingsProvider, int>((s) => s.weeklyGoalKm);
    if (uid == null) return const SizedBox.shrink();

    // Stream hanya dibuat ulang bila akun berganti.
    if (_stream == null || uid != _uid) {
      _uid = uid;
      _stream = _service.watchByUser(uid);
    }

    return Scaffold(
      appBar: const BsAppBar(title: 'Statistik'),
      body: StreamBuilder<List<Activity>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!);

          final list = snap.data;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.insert_chart_outlined,
              title: 'Belum ada statistik',
              message:
                  'Rekam aktivitas pertama Anda untuk melihat '
                  'ringkasan dan riwayatnya di sini.',
              action: BsButton(
                label: 'Mulai merekam',
                icon: Icons.play_arrow,
                onPressed: () => context.read<NavProvider>().go(1),
              ),
            );
          }
          return _buildContent(list, goalKm);
        },
      ),
    );
  }

  Widget _buildContent(List<Activity> all, int goalKm) {
    final list = StatsFilter.apply(all, period: _period, type: _type);
    final s = StatsSummary.from(list);
    final longest = s.longest;
    final insights = StatsInsights.from(list);
    // Streak gak ikut filter periode.
    final streak = StatsInsights.from(
      StatsFilter.apply(all, period: StatsPeriod.all, type: _type),
    );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        PeriodFilterBar(
          selected: _period,
          onChanged: (p) => setState(() => _period = p),
        ),
        const SizedBox(height: 8),
        TypeFilterChips(
          selected: _type,
          onChanged: (t) => setState(() => _type = t),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          const BsCard(
            child: Text(
              'Tidak ada aktivitas untuk filter ini.',
              style: TextStyle(color: BsColors.muted),
            ),
          )
        else ...[
          const _SectionTitle('Minggu ini'),
          BsCard(
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Aktivitas',
                    value: '${s.weekCount}',
                    big: true,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Jarak',
                    value: Fmt.km(s.weekDistanceM),
                    unit: 'km',
                    big: true,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Waktu',
                    value: Fmt.duration(s.weekDurationS),
                    big: true,
                  ),
                ),
              ],
            ),
          ),
          if (_type == null) ...[
            const SizedBox(height: 12),
            _GoalCard(summary: s, goalKm: goalKm),
          ],
          const SizedBox(height: 12),
          StreakCard(
            current: streak.currentStreak,
            longest: streak.longestStreak,
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Jarak 8 minggu terakhir (km)'),
          BsCard(child: WeeklyBarChart(weeks: s.weeks)),
          const SizedBox(height: 16),
          _SectionTitle(_period.totalTitle),
          BsCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(label: 'Aktivitas', value: '${s.count}'),
                    ),
                    Expanded(
                      child: StatTile(
                        label: 'Jarak',
                        value: Fmt.km(s.totalDistanceM),
                        unit: 'km',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: 'Waktu',
                        value: Fmt.duration(s.totalDurationS),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: BsColors.border),
                _buildByType(list),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Rekor pribadi'),
          PersonalRecordsCard(longest: longest, insights: insights),
          const SizedBox(height: 16),
          _SectionTitle('Riwayat (${list.length})'),
          for (final a in list) _HistoryTile(activity: a),
        ],
      ],
    );
  }

  Widget _buildByType(List<Activity> list) {
    return Row(
      children: [
        for (final type in ActivityType.values)
          Expanded(child: _buildTypeTotal(type, list)),
      ],
    );
  }

  Widget _buildTypeTotal(ActivityType type, List<Activity> list) {
    var count = 0;
    var distance = 0.0;
    for (final a in list) {
      if (a.type == type) {
        count += 1;
        distance += a.distanceM;
      }
    }

    return Column(
      children: [
        Icon(type.icon, color: type.color),
        const SizedBox(height: 4),
        Text(
          '${Fmt.km(distance)} km',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          '$count× ${type.label}',
          style: const TextStyle(fontSize: 12, color: BsColors.muted),
        ),
      ],
    );
  }
}

/// Kemajuan minggu ini menuju target jarak mingguan (diatur di Pengaturan).
class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.summary, required this.goalKm});

  final StatsSummary summary;
  final int goalKm;

  @override
  Widget build(BuildContext context) {
    final reached = summary.goalReached(goalKm);
    final color = reached ? BsColors.success : BsColors.primary;

    return BsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                reached ? Icons.emoji_events : Icons.flag_outlined,
                color: color,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Target mingguan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                child: const Text('Ubah'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(BsRadius.sm),
            child: LinearProgressIndicator(
              value: summary.goalProgress(goalKm),
              minHeight: 10,
              color: color,
              backgroundColor: BsColors.border,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${Fmt.km(summary.weekDistanceM)} dari $goalKm km '
            '(${summary.goalPercent(goalKm)}%)',
            style: const TextStyle(color: BsColors.muted),
          ),
          if (reached)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Target minggu ini tercapai. Kerja bagus!',
                style: TextStyle(
                  color: BsColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;

    return BsCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ActivityDetailScreen(activityId: a.id),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: a.type.color.withValues(alpha: 0.15),
            child: Icon(a.type.icon, color: a.type.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  Fmt.dateTime(a.startTime),
                  style: const TextStyle(fontSize: 12, color: BsColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${Fmt.km(a.distanceM)} km',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                Fmt.duration(a.durationS),
                style: const TextStyle(fontSize: 12, color: BsColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
