import 'package:latlong2/latlong.dart' show LatLng;

/// Nilai tetap yang dipakai di banyak tempat.
class AppConstants {
  AppConstants._();

  /// Nama aplikasi yang tampil di layar (bebas diganti).
  static const String appName = 'Lariku';

  /// Identitas aplikasi untuk server peta OpenStreetMap.
  /// Harus spesifik. Jangan memakai 'com.example...' karena bisa diblokir.
  static const String appPackageName = 'com.lariku.mobile';

  /// Lokasi logo. Taruh file logo Anda di assets/images/logo.png.
  static const String logoAsset = 'assets/images/logo.png';

  /// Server tile peta OpenStreetMap.
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Pusat peta bawaan (Monas, Jakarta) saat lokasi belum diketahui.
  static const LatLng defaultCenter = LatLng(-6.1754, 106.8272);
}
