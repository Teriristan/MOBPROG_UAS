import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/bootstrap_theme.dart';
import '../core/utils/formatters.dart';
import '../models/activity_type.dart';

// Grafik donut proporsi jarak per jenis aktivitas, digambar dengan CustomPainter tanpa package grafik.
class TypeDonutChart extends StatelessWidget {
  const TypeDonutChart({super.key, required this.distanceByType});

  // Total jarak per jenis.
  final Map<ActivityType, double> distanceByType;

  static const double _size = 130;

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final t in ActivityType.values)
        if ((distanceByType[t] ?? 0) > 0) (type: t, meters: distanceByType[t]!),
    ];
    final total = entries.fold<double>(0, (sum, e) => sum + e.meters);

    if (total <= 0) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: Text(
            'Belum ada jarak tercatat.',
            style: TextStyle(color: BsColors.muted),
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: _size,
          height: _size,
          child: CustomPaint(
            painter: _DonutPainter(
              slices: [
                for (final e in entries)
                  _Slice(e.meters / total, e.type.color),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Fmt.km(total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'km',
                    style: TextStyle(fontSize: 11, color: BsColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: e.type.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.type.label)),
                      Text(
                        '${(e.meters / total * 100).round()}%  ·  '
                        '${Fmt.km(e.meters)} km',
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
        ),
      ],
    );
  }
}

class _Slice {
  const _Slice(this.fraction, this.color);

  final double fraction;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices});

  final List<_Slice> slices;

  static const double _stroke = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final arcRect = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;

    var start = -math.pi / 2; // mulai dari jam 12
    for (final s in slices) {
      final sweep = 2 * math.pi * s.fraction;
      paint.color = s.color;
      canvas.drawArc(arcRect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) => true;
}