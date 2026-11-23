import 'package:flutter/material.dart';
import '../models/stats_period.dart';

// Pilihan rentang waktu minggu ini, bulan ini atau semua.
class PeriodFilterBar extends StatelessWidget {
  const PeriodFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final StatsPeriod selected;
  final ValueChanged<StatsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<StatsPeriod>(
        showSelectedIcon: false,
        segments: [
          for (final p in StatsPeriod.values)
            ButtonSegment<StatsPeriod>(value: p, label: Text(p.label)),
        ],
        selected: {selected},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}