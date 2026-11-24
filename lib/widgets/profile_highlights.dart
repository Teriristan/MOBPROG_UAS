import 'package:flutter/material.dart';

import '../core/theme/bootstrap_theme.dart';
import '../core/utils/dates.dart';
import '../core/utils/formatters.dart';
import '../models/activity.dart';
import 'bs/bs_card.dart';
import 'stat_tile.dart';

class ProfileHighlights extends StatelessWidget {
  const ProfileHighlights({super.key, required this.items});

  final List<Activity> items;

  static String formatPace(double secPerKm) {
    final total = secPerKm.round();
    final m = total ~/ 60;
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static double _paceOf(Activity a) => a.durationS / (a.distanceM / 1000);
  static Set<DateTime> activeDays(List<Activity> items) => <DateTime>{
    for (final a in items) Dates.startOfDay(a.startTime),
  };

  static int currentStreak(Set<DateTime> days, DateTime now) {
    var d = Dates.startOfDay(now);
    if (!days.contains(d)) d = DateTime(d.year, d.month, d.day - 1);
    var n = 0;
    while (days.contains(d)) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  static int longestStreak(Set<DateTime> days) {
    final sorted = days.toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final d in sorted) {
      if (prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    var totalM = 0.0;
    var totalS = 0;
    var longestM = 0.0;
    var longestS = 0;
    double? bestPace;
    var early = false;
    final types = <Object>{};

    for (final a in items) {
      totalM += a.distanceM;
      totalS += a.durationS;
      if (a.distanceM > longestM) longestM = a.distanceM;
      if (a.durationS > longestS) longestS = a.durationS;
      // pace hanya dihitung untuk aktivitas minimal 1 km supaya masuk akal
      if (a.distanceM >= 1000) {
        final p = _paceOf(a);
        if (bestPace == null || p < bestPace) bestPace = p;
      }
      if (a.startTime.hour < 6) early = true;
      types.add(a.type);
    }

    final avgM = totalM / items.length;
    final avgPace = totalM > 0 ? totalS / (totalM / 1000) : null;
    final longestStreakDays = longestStreak(activeDays(items));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _title('Rekor Pribadi'),
        const SizedBox(height: 8),
        BsCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Jarak terjauh',
                      value: Fmt.km(longestM),
                      unit: 'km',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: 'Durasi terlama',
                      value: Fmt.duration(longestS),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Pace terbaik',
                      value: bestPace == null ? '--:--' : formatPace(bestPace),
                      unit: '/km',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: 'Pace rata-rata',
                      value: avgPace == null ? '--:--' : formatPace(avgPace),
                      unit: '/km',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Rata-rata per aktivitas',
                      value: Fmt.km(avgM),
                      unit: 'km',
                    ),
                  ),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _title('Level Pelari'),
        const SizedBox(height: 8),
        _LevelCard(totalKm: totalM / 1000),
        const SizedBox(height: 16),
        _title('Pencapaian'),
        const SizedBox(height: 8),
        _Achievements(
          count: items.length,
          longestKm: longestM / 1000,
          totalKm: totalM / 1000,
          longestStreak: longestStreakDays,
          typeCount: types.length,
          earlyBird: early,
        ),
      ],
    );
  }

  Widget _title(String text) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );
}

class _Level {
  const _Level(this.name, this.minKm, this.icon);
  final String name;
  final double minKm;
  final IconData icon;
}

const _levels = <_Level>[
  _Level('Pemula', 0, Icons.directions_walk),
  _Level('Pelari', 25, Icons.directions_run),
  _Level('Pelari Tangguh', 100, Icons.local_fire_department),
  _Level('Pelari Elit', 250, Icons.emoji_events),
];

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.totalKm});

  final double totalKm;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    var idx = 0;
    for (var i = 0; i < _levels.length; i++) {
      if (totalKm >= _levels[i].minKm) idx = i;
    }
    final current = _levels[idx];
    final isMax = idx == _levels.length - 1;
    final next = isMax ? null : _levels[idx + 1];

    double progress = 1;
    String info = 'Level tertinggi tercapai!';
    if (next != null) {
      final span = next.minKm - current.minKm;
      progress = ((totalKm - current.minKm) / span).clamp(0.0, 1.0);
      final remain = (next.minKm - totalKm).clamp(0, double.infinity);
      info = '${remain.toStringAsFixed(1)} km lagi menuju ${next.name}';
    }

    return BsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(current.icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Total ${totalKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 12,
                        color: BsColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress, minHeight: 8),
          ),
          const SizedBox(height: 6),
          Text(
            info,
            style: const TextStyle(fontSize: 12, color: BsColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Badge {
  const _Badge(this.label, this.icon, this.unlocked);
  final String label;
  final IconData icon;
  final bool unlocked;
}

class _Achievements extends StatelessWidget {
  const _Achievements({
    required this.count,
    required this.longestKm,
    required this.totalKm,
    required this.longestStreak,
    required this.typeCount,
    required this.earlyBird,
  });

  final int count;
  final double longestKm;
  final double totalKm;
  final int longestStreak;
  final int typeCount;
  final bool earlyBird;

  @override
  Widget build(BuildContext context) {
    final badges = <_Badge>[
      _Badge('Aktivitas Pertama', Icons.flag, count >= 1),
      _Badge('5 Aktivitas', Icons.looks_5, count >= 5),
      _Badge('10 Aktivitas', Icons.filter_9_plus, count >= 10),
      _Badge('Lari 5K', Icons.route, longestKm >= 5),
      _Badge('Lari 10K', Icons.timeline, longestKm >= 10),
      _Badge('Half Marathon', Icons.military_tech, longestKm >= 21.1),
      _Badge('Total 100 km', Icons.public, totalKm >= 100),
      _Badge('Streak 3 Hari', Icons.local_fire_department, longestStreak >= 3),
      _Badge('Streak 7 Hari', Icons.whatshot, longestStreak >= 7),
      _Badge('Semua Jenis', Icons.category, typeCount >= 3),
      _Badge('Pelari Subuh', Icons.wb_twilight, earlyBird),
    ];

    final unlockedCount = badges.where((b) => b.unlocked).length;

    return BsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$unlockedCount dari ${badges.length} terbuka',
            style: const TextStyle(fontSize: 12, color: BsColors.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final b in badges) _BadgeTile(badge: b)],
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final _Badge badge;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final color = badge.unlocked ? primary : BsColors.muted;

    return SizedBox(
      width: 84,
      child: Opacity(
        opacity: badge.unlocked ? 1 : 0.45,
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                badge.unlocked ? badge.icon : Icons.lock_outline,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
