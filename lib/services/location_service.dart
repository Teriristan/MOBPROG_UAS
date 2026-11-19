import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Satu titik GPS yang sudah disederhanakan.
class GpsPoint {
  const GpsPoint({
    required this.latLng,
    required this.accuracy,
    required this.time,
  });

  final LatLng latLng;

  /// Akurasi dalam meter (makin kecil makin baik).
  final double accuracy;
  final DateTime time;
}

enum LocationAccess { granted, serviceDisabled, denied, deniedForever }

/// Pembungkus GPS (geolocator), plus mode simulasi untuk uji coba.
class LocationService {
  /// Memeriksa layanan lokasi dan meminta izin bila perlu.
  Future<LocationAccess> ensureAccess() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return LocationAccess.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) return LocationAccess.denied;
    if (permission == LocationPermission.deniedForever) {
      return LocationAccess.deniedForever;
    }
    return LocationAccess.granted;
  }

  static String messageFor(LocationAccess access) => switch (access) {
    LocationAccess.granted => '',
    LocationAccess.serviceDisabled =>
      'GPS belum aktif. Nyalakan layanan lokasi di perangkat.',
    LocationAccess.denied =>
      'Izin lokasi ditolak. Izinkan lokasi agar aktivitas bisa direkam.',
    LocationAccess.deniedForever =>
      'Izin lokasi ditolak permanen. Aktifkan lewat Pengaturan aplikasi.',
  };

  /// Posisi saat ini. Mengembalikan null bila gagal.
  /// Tanpa [askPermission], tidak ada permintaan izin yang muncul.
  Future<LatLng?> currentLatLng({bool askPermission = false}) async {
    try {
      if (askPermission) {
        final access = await ensureAccess();
        if (access != LocationAccess.granted) return null;
      } else {
        final permission = await Geolocator.checkPermission();
        final allowed =
            permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always;
        if (!allowed) return null;
        if (!await Geolocator.isLocationServiceEnabled()) return null;
      }

      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Aliran posisi GPS asli.
  Stream<GpsPoint> positionStream() {
    return Geolocator.getPositionStream(locationSettings: _settings()).map(
      (p) => GpsPoint(
        latLng: LatLng(p.latitude, p.longitude),
        accuracy: p.accuracy,
        time: DateTime.now(),
      ),
    );
  }

  /// Aliran posisi palsu untuk uji coba: berjalan memutari satu lingkaran
  /// (jari-jari 120 m) dengan kecepatan [speedMps] meter per detik.
  Stream<GpsPoint> simulatedStream({
    required LatLng start,
    required double speedMps,
  }) {
    const radius = 120.0;
    const metersPerDegLat = 111320.0;
    final metersPerDegLng =
        metersPerDegLat * math.cos(start.latitude * math.pi / 180);
    final centerLat = start.latitude;
    final centerLng = start.longitude - radius / metersPerDegLng;

    return Stream<GpsPoint>.periodic(const Duration(seconds: 1), (i) {
      final theta = (i + 1) * speedMps / radius;
      return GpsPoint(
        latLng: LatLng(
          centerLat + radius * math.sin(theta) / metersPerDegLat,
          centerLng + radius * math.cos(theta) / metersPerDegLng,
        ),
        accuracy: 5,
        time: DateTime.now(),
      );
    });
  }

  LocationSettings _settings() {
    if (kIsWeb) {
      return const LocationSettings(accuracy: LocationAccuracy.high);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 2),
        // Notifikasi ini menjaga perekaman tetap berjalan saat layar mati.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Lariku sedang merekam',
          notificationText: 'Aktivitas Anda sedang direkam.',
          enableWakeLock: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 3,
    );
  }
}
