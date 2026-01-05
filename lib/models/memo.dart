// lib/models/memo.dart
//
// Memo model for Private Memo app.
// - locationId is persisted in the memos table (foreign key to locations.id)
// - locationLabel is OPTIONAL and typically comes from a JOIN query (e.g. `locations.label AS locationLabel`)

class Memo {
  final int? id;
  final int userId;
  final String title;
  final String? content;
  final String updatedAt;

  /// FK to locations.id (nullable)
  final int? locationId;

  /// Convenience field for display (not stored in memos table).
  /// Populate it via JOIN queries, e.g. `l.label AS locationLabel`.
  final String? locationLabel;

  Memo({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.locationId,
    this.locationLabel,
  });

  /// Convert a SQLite query result (Map) into a Memo object.
  /// Supports both normal memo rows and JOIN results that include a location label.
  factory Memo.fromMap(Map<String, Object?> map) {
    // Some SELECTs may alias the location name/label differently; support common ones.
    final Object? locLabel = map.containsKey('locationLabel')
        ? map['locationLabel']
        : map['location_name'];

    return Memo(
      id: map['id'] as int?,
      userId: map['userId'] as int,
      title: map['title'] as String,
      content: map['content'] as String?,
      updatedAt: map['updatedAt'] as String,
      locationId: map['locationId'] as int?,
      locationLabel: locLabel as String?,
    );
  }

  /// Convert a Memo object into a Map for SQLite insert/update.
  /// NOTE: locationLabel is not persisted in the memos table.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'content': content,
      'updatedAt': updatedAt,
      'locationId': locationId,
    };
  }

  Memo copyWith({
    int? id,
    int? userId,
    String? title,
    String? content,
    String? updatedAt,
    int? locationId,
    String? locationLabel,
    bool clearLocation = false,
  }) {
    return Memo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      locationId: clearLocation ? null : (locationId ?? this.locationId),
      locationLabel: clearLocation
          ? null
          : (locationLabel ?? this.locationLabel),
    );
  }

  @override
  String toString() {
    return 'Memo{id: $id, userId: $userId, title: $title, updatedAt: $updatedAt, locationId: $locationId, locationLabel: $locationLabel}';
  }
}
