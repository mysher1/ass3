// lib/models/location_point.dart

class LocationPoint {
  final int? id;
  final int userId;
  final double lat;
  final double lng;
  final String? label;
  final String createdAt; // store as ISO-8601 (UTC recommended)

  LocationPoint({
    required this.id,
    required this.userId,
    required this.lat,
    required this.lng,
    required this.label,
    required this.createdAt,
  });

  factory LocationPoint.fromMap(Map<String, Object?> map) {
    return LocationPoint(
      id: map['id'] as int?,
      userId: map['userId'] as int,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      label: map['label'] as String?,
      createdAt: map['createdAt'] as String,
    );
    // Note: if your column names differ, align them here.
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'userId': userId,
      'latitude': lat,
      'longitude': lng,
      'label': label,
      'createdAt': createdAt,
    };
  }

  LocationPoint copyWith({
    int? id,
    int? userId,
    double? lat,
    double? lng,
    String? label,
    String? createdAt,
  }) {
    return LocationPoint(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'LocationPoint{id: $id, userId: $userId, lat: $lat, lng: $lng, label: $label, createdAt: $createdAt}';
  }
}
