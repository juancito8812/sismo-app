class Earthquake {
  final String id;
  final double magnitude;
  final String place;
  final DateTime time;
  final double latitude;
  final double longitude;
  final double depthKm;
  final String source;
  final int notified;

  const Earthquake({
    required this.id,
    required this.magnitude,
    required this.place,
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.depthKm,
    this.source = 'USGS',
    this.notified = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Earthquake && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  factory Earthquake.fromJson(Map<String, dynamic> json) {
    final props = json['properties'] ?? {};
    final geom = json['geometry'] ?? {};
    final coords = geom['coordinates'] ?? [];

    return Earthquake(
      id: json['id']?.toString() ?? '',
      magnitude: (props['mag'] ?? 0).toDouble(),
      place: props['place']?.toString() ?? '',
      time: DateTime.fromMillisecondsSinceEpoch((props['time'] ?? 0)),
      latitude: (coords.isNotEmpty ? coords[1] : 0).toDouble(),
      longitude: (coords.isNotEmpty ? coords[0] : 0).toDouble(),
      depthKm: (coords.isNotEmpty ? coords[2] : 0).toDouble(),
    );
  }
}
