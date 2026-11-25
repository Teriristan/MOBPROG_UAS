import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../core/constants.dart';
import '../core/theme/bootstrap_theme.dart';

class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.route,
    this.current,
    this.followCurrent = false,
    this.fitRoute = false,
    this.interactive = true,
    this.showEndpoints = false,
    this.color = BsColors.primary,
  });

  final List<LatLng> route;
  final LatLng? current;
  final bool followCurrent;
  final bool fitRoute;
  final bool interactive;
  final bool showEndpoints;
  final Color color;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final MapController _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final cur = widget.current;
    if (widget.followCurrent && cur != null && cur != oldWidget.current) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_ready) return;
        _controller.move(cur, _controller.camera.zoom);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final cur = widget.current;
    final canFit = widget.fitRoute && route.length >= 2;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter:
            cur ?? (route.isNotEmpty ? route.last : AppConstants.defaultCenter),
        initialZoom: 16,
        initialCameraFit: canFit
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(route),
                padding: const EdgeInsets.all(36),
                maxZoom: 17,
              )
            : null,
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        onMapReady: () => _ready = true,
      ),
      children: [
        TileLayer(
          urlTemplate: AppConstants.osmTileUrl,
          userAgentPackageName: AppConstants.appPackageName,
        ),
        if (route.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route,
                strokeWidth: 5,
                color: widget.color,
                borderStrokeWidth: 1.5,
                borderColor: Colors.white,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.showEndpoints && route.isNotEmpty)
              Marker(
                point: route.first,
                width: 20,
                height: 20,
                child: const _Dot(color: BsColors.success),
              ),
            if (widget.showEndpoints && route.length > 1)
              Marker(
                point: route.last,
                width: 20,
                height: 20,
                child: const _Dot(color: BsColors.danger),
              ),
            if (cur != null)
              Marker(
                point: cur,
                width: 24,
                height: 24,
                child: const _Dot(color: BsColors.primary),
              ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap contributors'),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4)],
      ),
    );
  }
}
