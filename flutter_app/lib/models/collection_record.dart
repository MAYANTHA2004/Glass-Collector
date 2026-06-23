/// A locally-saved collection record (offline-first).
/// Written to SQLite the moment a collection is confirmed on Screen 2,
/// independent of network state. `synced` tracks whether the final
/// "Sync to server" push (Screen 3) has confirmed it on the backend.
class CollectionRecord {
  final int? id; // local SQLite autoincrement id
  final int tripId;
  final int tripStopId;
  final String supplierCode;
  final double clearKg;
  final double colouredKg;
  final String condition;
  final DateTime timestamp;
  final bool synced;

  CollectionRecord({
    this.id,
    required this.tripId,
    required this.tripStopId,
    required this.supplierCode,
    required this.clearKg,
    required this.colouredKg,
    required this.condition,
    required this.timestamp,
    this.synced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trip_id': tripId,
      'trip_stop_id': tripStopId,
      'supplier_code': supplierCode,
      'clear_kg': clearKg,
      'coloured_kg': colouredKg,
      'condition': condition,
      'timestamp': timestamp.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  factory CollectionRecord.fromMap(Map<String, dynamic> map) {
    return CollectionRecord(
      id: map['id'] as int?,
      tripId: map['trip_id'] as int,
      tripStopId: map['trip_stop_id'] as int,
      supplierCode: map['supplier_code'] as String,
      clearKg: (map['clear_kg'] as num).toDouble(),
      colouredKg: (map['coloured_kg'] as num).toDouble(),
      condition: map['condition'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      synced: (map['synced'] as int) == 1,
    );
  }
}
