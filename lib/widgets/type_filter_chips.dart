import 'package:flutter/material.dart';
import '../core/theme/bootstrap_theme.dart';
import '../models/activity_type.dart';

// Pilih jenis aktivitas antara semua, lari, sepeda atau jalan.
class TypeFilterChips extends StatelessWidget {
  const TypeFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ActivityType? selected;
  final ValueChanged<ActivityType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          label: const Text('Semua'),
          selected: selected == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final t in ActivityType.values)
          ChoiceChip(
            avatar: Icon(t.icon, size: 18, color: t.color),
            label: Text(t.label),
            selected: selected == t,
            onSelected: (_) => onChanged(t),
          ),
      ],
    );
  }
}