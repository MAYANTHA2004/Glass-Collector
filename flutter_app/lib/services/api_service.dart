import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../models/trip_stop.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Thin wrapper around the .NET backend's REST endpoints.
/// Each method maps 1:1 to a controller action.
class ApiService {
  final String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  /// Screen 1: GET /api/trips/today
  Future<TripResponse> getTodayTrip({double? startLat, double? startLon}) async {
    final query = <String, String>{};
    if (startLat != null) query['startLat'] = startLat.toString();
    if (startLon != null) query['startLon'] = startLon.toString();

    final res = await http.get(_uri('/api/trips/today', query));
    if (res.statusCode != 200) {
      throw ApiException('Failed to load trip (${res.statusCode}): ${res.body}');
    }
    return TripResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Force a brand-new trip/route (handy for repeated demo runs).
  Future<TripResponse> createNewTrip({double? startLat, double? startLon}) async {
    final query = <String, String>{};
    if (startLat != null) query['startLat'] = startLat.toString();
    if (startLon != null) query['startLon'] = startLon.toString();

    final res = await http.post(_uri('/api/trips/new', query));
    if (res.statusCode != 200) {
      throw ApiException('Failed to create trip (${res.statusCode}): ${res.body}');
    }
    return TripResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Screen 2 check-in gate: POST /api/collections/verify
  /// Returns (isMatch, message, tripStopId).
  Future<Map<String, dynamic>> verifyBarcode({
    required int tripId,
    required String scannedSupplierCode,
  }) async {
    final res = await http.post(
      _uri('/api/collections/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tripId': tripId,
        'scannedSupplierCode': scannedSupplierCode,
      }),
    );
    if (res.statusCode != 200) {
      throw ApiException('Verify failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Screen 2 confirm: POST /api/collections/submit
  Future<Map<String, dynamic>> submitCollection({
    required int tripId,
    required int tripStopId,
    required String supplierCode,
    required double clearKg,
    required double colouredKg,
    required String condition,
    required DateTime collectedAtUtc,
  }) async {
    final res = await http.post(
      _uri('/api/collections/submit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tripId': tripId,
        'tripStopId': tripStopId,
        'supplierCode': supplierCode,
        'clearKg': clearKg,
        'colouredKg': colouredKg,
        'condition': condition,
        'collectedAtUtc': collectedAtUtc.toIso8601String(),
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 400) {
      throw ApiException('Submit failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Screen 3: GET /api/trips/{tripId}/report
  Future<Map<String, dynamic>> getTripReport(int tripId) async {
    final res = await http.get(_uri('/api/trips/$tripId/report'));
    if (res.statusCode != 200) {
      throw ApiException('Report failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Screen 3 "Sync to server": POST /api/collections/sync
  /// Pushes every locally stored record in one batch.
  Future<Map<String, dynamic>> syncRecords({
    required int tripId,
    required List<Map<String, dynamic>> records,
  }) async {
    final res = await http.post(
      _uri('/api/collections/sync'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'tripId': tripId, 'records': records}),
    );
    if (res.statusCode != 200) {
      throw ApiException('Sync failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
