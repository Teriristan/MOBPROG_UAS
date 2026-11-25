enum ActivityType {
  run('Lari', 3.0),
  ride('Sepeda', 7.0),
  walk('Jalan', 1.4);

  const ActivityType(this.label, this.simulatedSpeedMps);

  final String label;

  final double simulatedSpeedMps;

  bool get usesSpeed => this == ActivityType.ride;

  static ActivityType fromKey(String? key) {
    for (final t in ActivityType.values) {
      if (t.name == key) return t;
    }
    return ActivityType.run;
  }
}
