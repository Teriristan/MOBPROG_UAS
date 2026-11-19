import 'package:latlong2/latlong.dart' show LatLng;

class RouteUtils {
  RouteUtils._();

  /// Pengali yang mengubah derajat menjadi bilangan bulat di [encode]:
  /// 1 satuan = 0,00001 derajat (sekitar 1 meter).
  static const double scale = 1e5;

  /// Mengurangi jumlah titik rute (maksimal [maxPoints]) tanpa mengubah
  /// bentuknya secara berarti, supaya data di localStorage tidak terlalu besar.
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

  /// Memadatkan rute menjadi daftar bilangan bulat datar
  /// `[lat1, lng1, lat2, lng2, ...]` (derajat dikali [scale], dibulatkan).
  /// Bentuk ini jauh lebih hemat tempat daripada menyimpan tiap titik sebagai
  /// objek JSON, penting karena localStorage hanya muat sekitar 5 MB.
  static List<int> encode(List<LatLng> points) {
    final out = <int>[];
    for (final p in points) {
      out.add((p.latitude * scale).round());
      out.add((p.longitude * scale).round());
    }
    return out;
  }

  /// Kebalikan dari [encode]. Nilai yang bukan daftar bilangan diabaikan,
  /// sehingga data rusak tidak membuat aplikasi berhenti.
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
