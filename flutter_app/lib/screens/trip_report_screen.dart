import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/trip_session.dart';

/// Screen 3 - Trip Report
/// Shown after all stops are complete. Per-supplier summary, total kg,
/// route distance, trip duration, shortfall flags, and a final
/// "Sync to server" push of all locally stored records.
class TripReportScreen extends StatefulWidget {
  const TripReportScreen({super.key});

  @override
  State<TripReportScreen> createState() => _TripReportScreenState();
}

class _TripReportScreenState extends State<TripReportScreen> {
  Map<String, dynamic>? _report;
  bool _isLoadingReport = true;
  String? _loadError;

  bool _isSyncing = false;
  bool? _syncSuccess; // null = not attempted yet

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoadingReport = true;
      _loadError = null;
    });
    try {
      final report = await context.read<TripSession>().getReport();
      setState(() => _report = report);
    } catch (e) {
      setState(() => _loadError = e.toString());
    } finally {
      setState(() => _isLoadingReport = false);
    }
  }

  Future<void> _sync() async {
    setState(() {
      _isSyncing = true;
      _syncSuccess = null;
    });

    final success = await context.read<TripSession>().syncToServer();

    setState(() {
      _isSyncing = false;
      _syncSuccess = success;
    });

    // Refresh the report so any backend-side updates from sync are reflected.
    if (success) _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Report')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingReport) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load report.\n$_loadError', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadReport, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final report = _report!;
    final suppliers = report['suppliers'] as List<dynamic>;
    final totalKg = (report['totalKgCollected'] as num).toDouble();
    final distance = (report['totalDistanceKm'] as num).toDouble();
    final durationSeconds = (report['tripDurationSeconds'] as num).round();
    final duration = Duration(seconds: durationSeconds);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(totalKg: totalKg, distanceKm: distance, duration: duration),
        const SizedBox(height: 20),
        const Text('Per-supplier summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...suppliers.map((s) => _SupplierReportTile(supplier: s as Map<String, dynamic>)),
        const SizedBox(height: 24),
        _buildSyncSection(),
      ],
    );
  }

  Widget _buildSyncSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          icon: _isSyncing
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.cloud_upload),
          label: Text(_isSyncing ? 'Syncing...' : 'Sync to server'),
          onPressed: _isSyncing ? null : _sync,
        ),
        if (_syncSuccess != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_syncSuccess! ? Colors.green : Colors.orange).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: (_syncSuccess! ? Colors.green : Colors.orange).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  _syncSuccess! ? Icons.check_circle : Icons.warning_amber,
                  color: _syncSuccess! ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _syncSuccess!
                        ? 'All records synced to the server successfully.'
                        : "Sync failed — your data is safe locally. We'll retry next time you sync.",
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double totalKg;
  final double distanceKm;
  final Duration duration;
  const _SummaryCard({required this.totalKg, required this.distanceKm, required this.duration});

  @override
  Widget build(BuildContext context) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _Stat(label: 'Total collected', value: '${totalKg.toStringAsFixed(0)} kg'),
            _Stat(label: 'Distance', value: '${distanceKm.toStringAsFixed(1)} km'),
            _Stat(label: 'Duration', value: '${hours}h ${minutes}m'),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _SupplierReportTile extends StatelessWidget {
  final Map<String, dynamic> supplier;
  const _SupplierReportTile({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final name = supplier['supplierName'] as String;
    final isShortfall = supplier['isShortfall'] as bool? ?? false;
    final collectedClear = (supplier['collectedClearKg'] as num).toDouble();
    final collectedColoured = (supplier['collectedColouredKg'] as num).toDouble();
    final expectedClear = (supplier['expectedClearKg'] as num).toDouble();
    final expectedColoured = (supplier['expectedColouredKg'] as num).toDouble();
    final condition = supplier['condition'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(name),
        subtitle: Text(
          'Clear: ${collectedClear.toStringAsFixed(0)}/${expectedClear.toStringAsFixed(0)} kg · '
          'Coloured: ${collectedColoured.toStringAsFixed(0)}/${expectedColoured.toStringAsFixed(0)} kg'
          '${condition.isNotEmpty ? ' · $condition' : ''}',
        ),
        trailing: isShortfall
            ? const Tooltip(
                message: 'Collected below expected quantity',
                child: Icon(Icons.warning_amber, color: Colors.orange),
              )
            : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }
}
