import 'package:flutter/material.dart';
import '../core/theme/bootstrap_theme.dart';

// Grafik batang jumlah aktivitas per hari dalam seminggu.
class WeekdayBarChart extends StatelessWidget {
  const WeekdayBarChart({
    super.key,
    required this.counts,
    this.color = BsColors.primary,
  });

  // Jumlah aktivitas per hari, urut dari senin sampai minggu.
  final List<int> counts;
  final Color color;

  static const double _maxBarHeight = 96;
  static const List<String> _labels = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  @override
  Widget build(BuildContext context) {
    var maxCount = 0;
    for (final c in counts) {
      if (c > maxCount) maxCount = c;
    }

    return SizedBox(
      height: _maxBarHeight + 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: _Bar(
                label: _labels[i],
                count: i < counts.length ? counts[i] : 0,
                maxCount: maxCount,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.color,
  });

  final String label;
  final int count;
  final int maxCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final empty = count <= 0;
    final isTop = !empty && count == maxCount;
    final barHeight = empty
        ? 3.0
        : (WeekdayBarChart._maxBarHeight * count / maxCount)
              .clamp(6.0, WeekdayBarChart._maxBarHeight)
              .toDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          empty ? '' : '$count',
          style: const TextStyle(fontSize: 10, color: BsColors.muted),
        ),
        const SizedBox(height: 4),
        Container(
          height: barHeight,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: empty
                ? BsColors.border
                : (isTop ? color : color.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isTop ? BsColors.body : BsColors.muted,
            fontWeight: isTop ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}