import 'package:flutter/material.dart';
import '../core/theme/bootstrap_theme.dart';
import '../core/utils/formatters.dart';
import '../models/activity.dart';
import '../models/activity_type.dart';
import '../services/stats_insights.dart';
import 'bs/bs_card.dart';

// Rekor pribadi: jarak terjauh, durasi terlama, dan tercepat per jenis.
class PersonalRecordsCard extends StatelessWidget {
  const PersonalRecordsCard({
    super.key,
    required this.longest,
    required this.insights,
  });

  // Aktivitas dengan jarak terjauh.
  final Activity? longest;
  final StatsInsights insights;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    final far = longest;
    if (far != null) {
      rows.add(
        _RecordRow(
          icon: Icons.straighten,
          label: 'Jarak terjauh',
          value: Fmt.distance(far.distanceM),
          date: far.startTime,
        ),
      );
    }

    final long = insights.longestDuration;
    if (long != null) {
      rows.add(
        _RecordRow(
          icon: Icons.timer_outlined,
          label: 'Durasi terlama',
          value: Fmt.duration(long.durationS),
          date: long.startTime,
        ),
      );
    }

    for (final t in ActivityType.values) {
      final a = insights.fastestByType[t];
      if (a == null) continue;
      final value = t.usesSpeed
          ? '${Fmt.speed(a.distanceM, a.durationS)} km/jam'
          : '${Fmt.pace(a.distanceM, a.durationS)} /km';
      rows.add(
        _RecordRow(
          icon: t.icon,
          label: 'Tercepat • ${t.label}',
          value: value,
          date: a.startTime,
          color: t.color,
        ),
      );
    }

    return BsCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 20, color: BsColors.border),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.date,
    this.color = BsColors.muted,
  });

  final IconData icon;
  final String label;
  final String value;
  final DateTime date;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                Fmt.date(date),
                style: const TextStyle(fontSize: 12, color: BsColors.muted),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}