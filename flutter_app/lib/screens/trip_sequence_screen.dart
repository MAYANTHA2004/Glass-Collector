import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/trip_session.dart';
import '../models/trip_stop.dart';
import 'scan_collect_screen.dart';
import 'trip_report_screen.dart';

/// Screen 1 - Trip Sequence
/// On open, calls the backend for today's optimised stop order (Dijkstra +
/// Haversine), and shows total route distance, remaining stops, and each
/// supplier's live status (Pending / Next / Collected).
class TripSequenceScreen extends StatefulWidget {
  const TripSequenceScreen({super.key});

  @override
  State<TripSequenceScreen> createState() => _TripSequenceScreenState();
}

class _TripSequenceScreenState extends State<TripSequenceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripSession>().loadTodayTrip();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TripSession>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Route"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Start a new demo trip',
            onPressed: () => session.loadTodayTrip(forceNew: true),
          ),
        ],
      ),
      body: _buildBody(context, session),
      floatingActionButton: session.trip != null && !session.allStopsCollected
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan next stop'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScanCollectScreen()),
              ),
            )
          : (session.trip != null && session.allStopsCollected
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.summarize),
                  label: const Text('View trip report'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TripReportScreen()),
                  ),
                )
              : null),
    );
  }

  Widget _buildBody(BuildContext context, TripSession session) {
    if (session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (session.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'Could not load route.\n${session.errorMessage}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => session.loadTodayTrip(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final trip = session.trip;
    if (trip == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: () => session.loadTodayTrip(),
      child: Column(
        children: [
          _SummaryHeader(trip: trip),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: trip.stops.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) => _StopTile(stop: trip.stops[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final TripResponse trip;
  const _SummaryHeader({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Row(
        children: [
          Expanded(
            child: _StatBlock(
              icon: Icons.route,
              label: 'Route distance',
              value: '${trip.totalDistanceKm.toStringAsFixed(1)} km',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.3)),
          Expanded(
            child: _StatBlock(
              icon: Icons.flag,
              label: 'Remaining stops',
              value: '${trip.remainingStops} / ${trip.stops.length}',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatBlock({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

class _StopTile extends StatelessWidget {
  final TripStop stop;
  const _StopTile({required this.stop});

  Color _statusColor(BuildContext context) {
    switch (stop.status) {
      case 'Collected':
        return Colors.green;
      case 'Next':
        return Theme.of(context).colorScheme.primary;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon() {
    switch (stop.status) {
      case 'Collected':
        return Icons.check_circle;
      case 'Next':
        return Icons.navigation;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text(
          '${stop.sequenceNumber}',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(stop.supplierName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${stop.address}\n+${stop.distanceFromPreviousKm.toStringAsFixed(1)} km from previous · '
        'Expect ${(stop.expectedClearKg + stop.expectedColouredKg).toStringAsFixed(0)} kg',
      ),
      isThreeLine: true,
      trailing: Icon(_statusIcon(), color: color),
    );
  }
}
