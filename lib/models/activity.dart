import 'package:latlong2/latlong.dart' show LatLng;

import '../core/utils/route_utils.dart';
import 'activity_type.dart';

class Activity {
  const Activity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.title,
    required this.type,
    required this.distanceM,
    required this.durationS,
    required this.startTime,
    this.description = '',
    this.route = const <LatLng>[],
    this.kudosBy = const <String>[],
    this.commentsCount = 0,
  });

  final String id;
  final String userId;
  final String userName;
  final String title;
  final ActivityType type;
  final String description;
  final double distanceM;
  final int durationS;
  final DateTime startTime;
  final List<LatLng> route;
  final List<String> kudosBy;

  final int commentsCount;

  int get kudosCount => kudosBy.length;

  bool isKudosBy(String? uid) => uid != null && kudosBy.contains(uid);

  Activity copyWith({
    String? userName,
    List<String>? kudosBy,
    int? commentsCount,
  }) {
    return Activity(
      id: id,
      userId: userId,
      userName: userName ?? this.userName,
      title: title,
      type: type,
      description: description,
      distanceM: distanceM,
      durationS: durationS,
      startTime: startTime,
      route: route,
      kudosBy: kudosBy ?? this.kudosBy,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'userName': userName,
      'title': title,
      'type': type.name,
      'description': description,
      'distanceM': distanceM,
      'durationS': durationS,
      'startTime': startTime.millisecondsSinceEpoch,
      'route': RouteUtils.encode(route),
      'kudosBy': kudosBy,
    };
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    final rawKudos = (json['kudosBy'] as List<dynamic>?) ?? const <dynamic>[];
    return Activity(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: (json['userName'] as String?) ?? 'Pengguna',
      title: (json['title'] as String?) ?? 'Aktivitas',
      type: ActivityType.fromKey(json['type'] as String?),
      description: (json['description'] as String?) ?? '',
      distanceM: ((json['distanceM'] as num?) ?? 0).toDouble(),
      durationS: ((json['durationS'] as num?) ?? 0).toInt(),
      startTime: DateTime.fromMillisecondsSinceEpoch(
        ((json['startTime'] as num?) ?? 0).toInt(),
      ),
      route: RouteUtils.decode(json['route']),
      kudosBy: rawKudos.whereType<String>().toList(),
    );
  }
}
