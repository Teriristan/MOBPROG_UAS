import 'package:flutter/material.dart';

import '../core/theme/bootstrap_theme.dart';
import '../core/utils/formatters.dart';
import '../services/stats_service.dart';

class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({
    super.key,
    required this.weeks,
    this.color = BsColors.primary,
  });

  final List<WeekBar> weeks;
  final Color color;

  static const double _maxBarHeight = 96;

  @override
  Widget build(BuildContext context) {
    var maxM = 0.0;
    for (final w in weeks) {
      if (w.distanceM > maxM) maxM = w.distanceM;
    }

    return SizedBox(
      height: _maxBarHeight + 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < weeks.length; i++)
            Expanded(
              child: _Bar(
                week: weeks[i],
                ratio: maxM <= 0 ? 0.0 : weeks[i].distanceM / maxM,
                color: color,
                isCurrent: i == weeks.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.week,
    required this.ratio,
    required this.color,
    required this.isCurrent,
  });

  final WeekBar week;
  final double ratio;
  final Color color;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final empty = week.distanceM <= 0;
    final barHeight = empty
        ? 3.0
        : (WeeklyBarChart._maxBarHeight * ratio)
              .clamp(6.0, WeeklyBarChart._maxBarHeight)
              .toDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          empty ? '' : (week.distanceM / 1000).toStringAsFixed(1),
          style: const TextStyle(fontSize: 10, color: BsColors.muted),
        ),
        const SizedBox(height: 4),
        Container(
          height: barHeight,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: empty
                ? BsColors.border
                : (isCurrent ? color : color.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          Fmt.shortDate(week.start),
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: 10,
            color: isCurrent ? BsColors.body : BsColors.muted,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
