import 'package:flutter/material.dart';
import '../core/theme/bootstrap_theme.dart';
import 'bs/bs_card.dart';
import 'stat_tile.dart';

// Streak aktivitas
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.current, required this.longest});

  final int current;
  final int longest;

  @override
  Widget build(BuildContext context) {
    final active = current > 0;

    return BsCard(
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department,
            size: 36,
            color: active ? BsColors.orange : BsColors.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatTile(
              label: 'Streak sekarang',
              value: '$current',
              unit: 'hari',
              big: true,
              color: active ? BsColors.orange : null,
            ),
          ),
          Expanded(
            child: StatTile(
              label: 'Terpanjang',
              value: '$longest',
              unit: 'hari',
              big: true,
            ),
          ),
        ],
      ),
    );
  }
}