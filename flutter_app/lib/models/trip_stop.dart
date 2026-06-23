/// Mirrors the backend's TripStopDto (Screen 1 / Screen 2 data per stop).
class TripStop {
  final int tripStopId;
  final int supplierId;
  final String supplierCode;
  final String supplierName;
  final String address;
  final double latitude;
  final double longitude;
  final int sequenceNumber;
  final double distanceFromPreviousKm;
  final double expectedClearKg;
  final double expectedColouredKg;
  String status; // Pending | Next | Collected

  TripStop({
    required this.tripStopId,
    required this.supplierId,
    required this.supplierCode,
    required this.supplierName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.sequenceNumber,
    required this.distanceFromPreviousKm,
    required this.expectedClearKg,
    required this.expectedColouredKg,
    required this.status,
  });

  factory TripStop.fromJson(Map<String, dynamic> json) {
    return TripStop(
      tripStopId: json['tripStopId'] as int,
      supplierId: json['supplierId'] as int,
      supplierCode: json['supplierCode'] as String,
      supplierName: json['supplierName'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      sequenceNumber: json['sequenceNumber'] as int,
      distanceFromPreviousKm: (json['distanceFromPreviousKm'] as num).toDouble(),
      expectedClearKg: (json['expectedClearKg'] as num).toDouble(),
      expectedColouredKg: (json['expectedColouredKg'] as num).toDouble(),
      status: json['status'] as String,
    );
  }
}

/// Mirrors the backend's TripResponseDto (Screen 1 payload).
class TripResponse {
  final int tripId;
  final double totalDistanceKm;
  final int remainingStops;
  final List<TripStop> stops;

  TripResponse({
    required this.tripId,
    required this.totalDistanceKm,
    required this.remainingStops,
    required this.stops,
  });

  factory TripResponse.fromJson(Map<String, dynamic> json) {
    return TripResponse(
      tripId: json['tripId'] as int,
      totalDistanceKm: (json['totalDistanceKm'] as num).toDouble(),
      remainingStops: json['remainingStops'] as int,
      stops: (json['stops'] as List)
          .map((s) => TripStop.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
