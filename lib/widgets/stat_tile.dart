import 'package:flutter/material.dart';

import '../core/theme/bootstrap_theme.dart';
import '../core/utils/formatters.dart';
import '../models/activity_type.dart';

/// Satu angka statistik: label kecil di atas, nilai besar di bawah.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.big = false,
    this.color,
  });

  final String label;
  final String value;
  final String? unit;
  final bool big;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
            color: BsColors.muted,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: big ? 30 : 20,
                  fontWeight: FontWeight.w700,
                  color: color ?? BsColors.body,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: const TextStyle(fontSize: 12, color: BsColors.muted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Tiga angka utama aktivitas: jarak, waktu, dan pace (atau kecepatan
/// untuk sepeda).
class ActivityStatsRow extends StatelessWidget {
  const ActivityStatsRow({
    super.key,
    required this.distanceM,
    required this.durationS,
    required this.type,
    this.big = false,
  });

  final double distanceM;
  final int durationS;
  final ActivityType type;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: 'Jarak',
            value: Fmt.km(distanceM),
            unit: 'km',
            big: big,
          ),
        ),
        Expanded(
          child: StatTile(
            label: 'Waktu',
            value: Fmt.duration(durationS),
            big: big,
          ),
        ),
        Expanded(
          child: type.usesSpeed
              ? StatTile(
                  label: 'Kecepatan',
                  value: Fmt.speed(distanceM, durationS),
                  unit: 'km/j',
                  big: big,
                )
              : StatTile(
                  label: 'Pace',
                  value: Fmt.pace(distanceM, durationS),
                  unit: '/km',
                  big: big,
                ),
        ),
      ],
    );
  }
}
