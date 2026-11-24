import 'package:latlong2/latlong.dart' show LatLng;

class AppConstants {
  AppConstants._();
  static const String appName = 'Lariku';

  static const String appPackageName = 'com.lariku.mobile';

  static const String logoAsset = 'assets/images/logo.png';

  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const LatLng defaultCenter = LatLng(-6.1754, 106.8272);
}
