import 'package:latlong2/latlong.dart' show LatLng;

class RouteUtils {
  RouteUtils._();

  static const double scale = 1e5;

  static List<LatLng> simplify(List<LatLng> points, {int maxPoints = 800}) {
    if (points.length <= maxPoints || maxPoints < 2) {
      return List<LatLng>.of(points);
    }
    final result = <LatLng>[];
    final step = (points.length - 1) / (maxPoints - 1);
    for (var i = 0; i < maxPoints; i++) {
      result.add(points[(i * step).round()]);
    }
    return result;
  }

  static List<int> encode(List<LatLng> points) {
    final out = <int>[];
    for (final p in points) {
      out.add((p.latitude * scale).round());
      out.add((p.longitude * scale).round());
    }
    return out;
  }

  static List<LatLng> decode(Object? raw) {
    if (raw is! List<dynamic>) return const <LatLng>[];
    final result = <LatLng>[];
    for (var i = 0; i + 1 < raw.length; i += 2) {
      final lat = raw[i];
      final lng = raw[i + 1];
      if (lat is num && lng is num) {
        result.add(LatLng(lat / scale, lng / scale));
      }
    }
    return result;
  }
}
