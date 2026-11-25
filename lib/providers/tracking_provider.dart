import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:latlong2/latlong.dart' show LatLng;

import '../core/constants.dart';
import '../models/activity_type.dart';
import '../services/location_service.dart';
import 'settings_provider.dart';

enum TrackingStatus { idle, recording, paused, finished }

class TrackingProvider extends ChangeNotifier {
  TrackingProvider({LocationService? location, SettingsProvider? settings})
    : _location = location ?? LocationService(),
      _settings = settings {
    final s = settings;
    if (s != null) {
      _type = _defaultType = s.defaultType;
      _simulate = _defaultSimulate = s.simulateByDefault;
      s.addListener(_onSettingsChanged);
    }
  }

  final LocationService _location;
  final SettingsProvider? _settings;

  ActivityType _defaultType = ActivityType.run;
  bool _defaultSimulate = false;
  bool _defaultsPending = false;

  static const double _maxAccuracyM = 40;
  static const double _minStepM = 2;
  static const double _maxSpeedMps = 25;

  TrackingStatus _status = TrackingStatus.idle;
  ActivityType _type = ActivityType.run;
  bool _simulate = false;
  String? _error;

  final List<LatLng> _route = <LatLng>[];
  double _distanceM = 0;
  Duration _accumulated = Duration.zero;
  DateTime? _segmentStart;
  DateTime? _startedAt;

  LatLng? _current;
  LatLng? _lastCounted;
  DateTime? _lastTime;

  StreamSubscription<GpsPoint>? _sub;
  Timer? _ticker;
  bool _disposed = false;

  TrackingStatus get status => _status;
  ActivityType get type => _type;
  bool get simulate => _simulate;
  String? get error => _error;
  List<LatLng> get route => UnmodifiableListView<LatLng>(_route);
  double get distanceM => _distanceM;
  LatLng? get current => _current;
  DateTime? get startedAt => _startedAt;

  bool get isActive =>
      _status == TrackingStatus.recording || _status == TrackingStatus.paused;

  int get elapsedS => _elapsedNow().inSeconds;

  Duration _elapsedNow() {
    final start = _segmentStart;
    if (start == null) return _accumulated;
    return _accumulated + DateTime.now().difference(start);
  }

  void _onSettingsChanged() {
    final s = _settings;
    if (s == null) return;
    if (s.defaultType == _defaultType &&
        s.simulateByDefault == _defaultSimulate) {
      return;
    }
    _defaultType = s.defaultType;
    _defaultSimulate = s.simulateByDefault;

    if (_status == TrackingStatus.idle) {
      _type = _defaultType;
      _simulate = _defaultSimulate;
      notifyListeners();
    } else {
      _defaultsPending = true;
    }
  }

  void setType(ActivityType type) {
    if (_status != TrackingStatus.idle) return;
    _type = type;
    notifyListeners();
  }

  void setSimulate(bool value) {
    if (_status != TrackingStatus.idle) return;
    _simulate = value;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> locate({bool ask = false}) async {
    if (isActive) return;

    if (ask) {
      final access = await _location.ensureAccess();
      if (access != LocationAccess.granted) {
        _error = LocationService.messageFor(access);
        notifyListeners();
        return;
      }
    }

    final p = await _location.currentLatLng();
    if (p != null) {
      _current = p;
      _error = null;
    } else if (ask) {
      _error = 'Lokasi belum bisa dibaca. Coba lagi di tempat terbuka.';
    }
    notifyListeners();
  }

  Future<void> start() async {
    if (_status != TrackingStatus.idle) return;
    _error = null;

    final simulate = _simulate;
    final type = _type;
    LatLng origin = AppConstants.defaultCenter;

    if (simulate) {
      origin =
          _current ??
          await _location.currentLatLng() ??
          AppConstants.defaultCenter;
    } else {
      final access = await _location.ensureAccess();
      if (access != LocationAccess.granted) {
        _error = LocationService.messageFor(access);
        notifyListeners();
        return;
      }
    }

    if (_status != TrackingStatus.idle) return;

    _route.clear();
    _distanceM = 0;
    _accumulated = Duration.zero;
    _lastCounted = null;
    _lastTime = null;
    _startedAt = DateTime.now();
    _segmentStart = _startedAt;
    _status = TrackingStatus.recording;

    final Stream<GpsPoint> stream = simulate
        ? _location.simulatedStream(
            start: origin,
            speedMps: type.simulatedSpeedMps,
          )
        : _location.positionStream();

    _sub = stream.listen(
      _onPoint,
      onError: (Object e) {
        _error = 'Sinyal GPS bermasalah. Pastikan GPS aktif.';
        notifyListeners();
      },
    );
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
    notifyListeners();
  }

  void _onPoint(GpsPoint p) {
    _current = p.latLng;

    if (_status == TrackingStatus.recording && p.accuracy <= _maxAccuracyM) {
      final last = _lastCounted;
      final lastTime = _lastTime;

      if (last == null || lastTime == null) {
        _lastCounted = p.latLng;
        _lastTime = p.time;
        _route.add(p.latLng);
      } else {
        final d = Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          p.latLng.latitude,
          p.latLng.longitude,
        );
        final seconds = p.time.difference(lastTime).inMilliseconds / 1000;
        final speed = seconds > 0 ? d / seconds : 0.0;

        if (d >= _minStepM && speed <= _maxSpeedMps) {
          _distanceM += d;
          _route.add(p.latLng);
          _lastCounted = p.latLng;
          _lastTime = p.time;
        }
      }
    }
    notifyListeners();
  }

  void pause() {
    if (_status != TrackingStatus.recording) return;
    _accumulated = _elapsedNow();
    _segmentStart = null;
    _status = TrackingStatus.paused;
    notifyListeners();
  }

  void resume() {
    if (_status != TrackingStatus.paused) return;
    _segmentStart = DateTime.now();
    // Jarak selama jeda tidak dihitung.
    _lastCounted = null;
    _lastTime = null;
    _status = TrackingStatus.recording;
    notifyListeners();
  }

  void finish() {
    if (!isActive) return;
    _accumulated = _elapsedNow();
    _segmentStart = null;
    _stopSources();
    _status = TrackingStatus.finished;
    notifyListeners();
  }

  void reset() {
    _stopSources();
    _status = TrackingStatus.idle;
    _route.clear();
    _distanceM = 0;
    _accumulated = Duration.zero;
    _segmentStart = null;
    _startedAt = null;
    _lastCounted = null;
    _lastTime = null;
    _error = null;
    if (_defaultsPending) {
      _type = _defaultType;
      _simulate = _defaultSimulate;
      _defaultsPending = false;
    }
    notifyListeners();
  }

  void _stopSources() {
    _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _settings?.removeListener(_onSettingsChanged);
    _stopSources();
    super.dispose();
  }
}
