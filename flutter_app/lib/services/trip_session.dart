import 'package:flutter/foundation.dart';
import '../models/trip_stop.dart';
import '../models/collection_record.dart';
import 'api_service.dart';
import 'local_database.dart';

/// Shared trip state across Screen 1 -> 2 -> 3. Holds the loaded trip,
/// tracks which stop is currently expected, and exposes the actions each
/// screen needs (load route, verify scan, submit collection, sync).
class TripSession extends ChangeNotifier {
  final ApiService _api = ApiService();
  final LocalDatabase _localDb = LocalDatabase();

  TripResponse? trip;
  bool isLoading = false;
  String? errorMessage;
  DateTime? tripStartedAt;

  TripStop? get currentStop {
    if (trip == null) return null;
    try {
      return trip!.stops.firstWhere((s) => s.status != 'Collected');
    } catch (_) {
      return null; // all collected
    }
  }

  bool get allStopsCollected =>
      trip != null && trip!.stops.every((s) => s.status == 'Collected');

  Future<void> loadTodayTrip({bool forceNew = false}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      trip = forceNew ? await _api.createNewTrip() : await _api.getTodayTrip();
      tripStartedAt ??= DateTime.now();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Screen 2 step 1: verify the scanned barcode against the expected stop.
  Future<Map<String, dynamic>> verifyScan(String scannedCode) async {
    if (trip == null) throw Exception('No active trip.');
    return _api.verifyBarcode(tripId: trip!.tripId, scannedSupplierCode: scannedCode);
  }

  /// Screen 2 step 2: confirm quantities. Always saves locally first
  /// (offline-first), then best-effort pushes to the backend immediately.
  /// If that immediate push fails (no connectivity), the record stays
  /// safely queued for the Screen 3 sync.
  Future<void> confirmCollection({
    required int tripStopId,
    required String supplierCode,
    required double clearKg,
    required double colouredKg,
    required String condition,
  }) async {
    final now = DateTime.now();

    // 1. Save locally first — this must never fail silently.
    await _localDb.insertRecord(CollectionRecord(
      tripId: trip!.tripId,
      tripStopId: tripStopId,
      supplierCode: supplierCode,
      clearKg: clearKg,
      colouredKg: colouredKg,
      condition: condition,
      timestamp: now,
    ));

    // 2. Update in-memory trip state so Screen 1/2 UI reflects it immediately.
    final stop = trip!.stops.firstWhere((s) => s.tripStopId == tripStopId);
    stop.status = 'Collected';
    final next = trip!.stops.firstWhere(
      (s) => s.status == 'Pending',
      orElse: () => stop,
    );
    if (next.tripStopId != stop.tripStopId) next.status = 'Next';
    notifyListeners();

    // 3. Best-effort immediate push. Not required to succeed — Screen 3
    // sync is the authoritative final push, this just keeps the backend
    // fresh during the trip when connectivity is available.
    try {
      await _api.submitCollection(
        tripId: trip!.tripId,
        tripStopId: tripStopId,
        supplierCode: supplierCode,
        clearKg: clearKg,
        colouredKg: colouredKg,
        condition: condition,
        collectedAtUtc: now.toUtc(),
      );
    } catch (_) {
      // Offline or backend unreachable — fine, data is safe locally.
    }
  }

  /// Screen 3 "Sync to server": pushes every locally stored record for
  /// this trip in one batch. Returns true on full success.
  Future<bool> syncToServer() async {
    if (trip == null) return false;
    final unsynced = await _localDb.getUnsyncedRecords(trip!.tripId);

    if (unsynced.isEmpty) return true; // nothing to push, already synced

    final records = unsynced
        .map((r) => {
              'supplierCode': r.supplierCode,
              'tripStopId': r.tripStopId,
              'clearKg': r.clearKg,
              'colouredKg': r.colouredKg,
              'condition': r.condition,
              'collectedAtUtc': r.timestamp.toUtc().toIso8601String(),
            })
        .toList();

    try {
      final result = await _api.syncRecords(tripId: trip!.tripId, records: records);
      final accepted = result['recordsAccepted'] as int? ?? 0;

      if (accepted > 0) {
        for (final r in unsynced.take(accepted)) {
          if (r.id != null) await _localDb.markSynced(r.id!);
        }
      }
      return (result['success'] as bool?) ?? false;
    } catch (_) {
      return false; // stays queued locally, safe to retry
    }
  }

  Future<Map<String, dynamic>> getReport() async {
    if (trip == null) throw Exception('No active trip.');
    return _api.getTripReport(trip!.tripId);
  }

  void reset() {
    trip = null;
    tripStartedAt = null;
    errorMessage = null;
    notifyListeners();
  }
}
