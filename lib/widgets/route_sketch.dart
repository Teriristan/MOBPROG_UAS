import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../core/theme/bootstrap_theme.dart';

class RouteSketch extends StatelessWidget {
  const RouteSketch({
    super.key,
    required this.route,
    this.color = BsColors.primary,
    this.height = 120,
  });

  final List<LatLng> route;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(BsRadius.md),
      ),
      child: route.length < 2
          ? const Center(child: Icon(Icons.timeline, color: BsColors.muted))
          : CustomPaint(painter: _RoutePainter(route, color)),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.route, this.color);

  final List<LatLng> route;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 14.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    if (w <= 0 || h <= 0) return;

    var minLat = route.first.latitude;
    var maxLat = minLat;
    var minLng = route.first.longitude;
    var maxLng = minLng;
    for (final p in route) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final lngScale = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final spanX = math.max((maxLng - minLng) * lngScale, 1e-9);
    final spanY = math.max(maxLat - minLat, 1e-9);
    final scale = math.min(w / spanX, h / spanY);
    final offX = pad + (w - spanX * scale) / 2;
    final offY = pad + (h - spanY * scale) / 2;

    Offset toOffset(LatLng p) => Offset(
      offX + (p.longitude - minLng) * lngScale * scale,
      offY + (maxLat - p.latitude) * scale,
    );

    final first = toOffset(route.first);
    final path = Path()..moveTo(first.dx, first.dy);
    for (final p in route.skip(1)) {
      final o = toOffset(p);
      path.lineTo(o.dx, o.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(first, 5, Paint()..color = BsColors.success);
    canvas.drawCircle(
      toOffset(route.last),
      5,
      Paint()..color = BsColors.danger,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.route != route || oldDelegate.color != color;
}
