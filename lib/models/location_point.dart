// lib/models/location_point.dart
//
// LocationPoint model for SQLite 'locations' table.
//
// IMPORTANT (DB column names):
// app_database.dart uses: id, userId, label, latitude, longitude, createdAt
//
// This model is backward-compatible with older code that used keys: lat/lng.
// It also avoids runtime crashes when latitude/longitude are null in older rows.

class LocationPoint {
  final int? id;
  final int userId;
  final double lat;
  final double lng;
  final String? label;
  final String createdAt; // ISO-8601 (UTC recommended)

  LocationPoint({
    required this.id,
    required this.userId,
    required this.lat,
    required this.lng,
    required this.label,
    required this.createdAt,
  });

  /// Prefer showing the user-friendly label; otherwise fall back to coordinates.
  String get displayLabel {
    final t = (label ?? '').trim();
    if (t.isNotEmpty) return t;
    return 'Lat ${lat.toStringAsFixed(4)}, Lng ${lng.toStringAsFixed(4)}';
  }

  static double _toDoubleOr(double? v, double fallback) => v ?? fallback;

  static double _readDouble(
      Map<String, Object?> map, List<String> keys, double fallback) {
    for (final k in keys) {
      final raw = map[k];
      if (raw == null) continue;
      if (raw is num) return raw.toDouble();
      if (raw is String) {
        final parsed = double.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  factory LocationPoint.fromMap(Map<String, Object?> map) {
    final now = DateTime.now().toUtc().toIso8601String();

    // Accept both new (latitude/longitude) and old (lat/lng) keys.
    final lat = _readDouble(map, const ['latitude', 'lat'], 0.0);
    final lng = _readDouble(map, const ['longitude', 'lng'], 0.0);

    return LocationPoint(
      id: map['id'] as int?,
      userId: (map['userId'] as num?)?.toInt() ?? 0,
      lat: lat,
      lng: lng,
      label: map['label'] as String?,
      createdAt: (map['createdAt'] as String?) ?? now,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'userId': userId,
      // DB columns are latitude/longitude
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
