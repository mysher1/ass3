// lib/models/location_point.dart
//
// Represents a saved location for a specific user.
// Stored in SQLite `locations` table.
//
// Notes for Map + Memo feature:
// - `label` is what you display in the UI (e.g., "Library", "Kuala Lumpur").
// - If label is null/empty, `displayLabel` provides a safe fallback like "Lat 3.1400, Lng 101.6869".

class LocationPoint {
  final int? id;
  final int userId;
  final double lat;
  final double lng;

  /// Human-friendly name for this point (nullable).
  final String? label;

  /// Stored as ISO-8601 string (UTC recommended)
  final String createdAt;

  const LocationPoint({
    required this.id,
    required this.userId,
    required this.lat,
    required this.lng,
    required this.label,
    required this.createdAt,
  });

  /// A safe string to show in UI even when label is missing.
  String get displayLabel {
    final trimmed = label?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return 'Lat ${lat.toStringAsFixed(4)}, Lng ${lng.toStringAsFixed(4)}';
  }

  /// Create from a SQLite row.
  /// Supports common alternative key names just in case:
  /// - lat may appear as `lat` or `latitude`
  /// - lng may appear as `lng` or `longitude`
  factory LocationPoint.fromMap(Map<String, Object?> map) {
    final Object? latObj = map['lat'] ?? map['latitude'];
    final Object? lngObj = map['lng'] ?? map['longitude'];

    double toDouble(Object? v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return LocationPoint(
      id: map['id'] as int?,
      userId: map['userId'] as int,
      lat: toDouble(latObj),
      lng: toDouble(lngObj),
      label: map['label'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }

  /// Convert to a SQLite map for insert/update.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'userId': userId,
      'lat': lat,
      'lng': lng,
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
