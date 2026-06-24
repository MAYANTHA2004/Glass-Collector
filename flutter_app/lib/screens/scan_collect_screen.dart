import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/trip_session.dart';
import '../models/trip_stop.dart';
import 'trip_report_screen.dart';

/// Screen 2 - Scan & Collect
/// Shows the next destination, gates the quantity form behind a successful
/// barcode scan (decoded supplier ID must match the expected stop), then
/// posts the confirmed collection to the backend and advances to the next
/// stop. The barcode is the ONLY way to identify/update a supplier record
/// — there is no manual override.
class ScanCollectScreen extends StatefulWidget {
  const ScanCollectScreen({super.key});

  @override
  State<ScanCollectScreen> createState() => _ScanCollectScreenState();
}

class _ScanCollectScreenState extends State<ScanCollectScreen> {
  final MobileScannerController _scannerController = MobileScannerController();

  bool _isScanning = false;
  bool _isVerifying = false;
  bool _formUnlocked = false;
  String? _verifyError;
  TripStop? _matchedStop;

  final _clearKgController = TextEditingController();
  final _colouredKgController = TextEditingController();
  String _condition = 'Good';

  bool _isSubmitting = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _clearKgController.dispose();
    _colouredKgController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isVerifying || _formUnlocked) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() {
      _isScanning = false;
      _isVerifying = true;
      _verifyError = null;
    });

    final session = context.read<TripSession>();
    try {
      final result = await session.verifyScan(rawValue.trim());
      final isMatch = result['isMatch'] as bool? ?? false;
      final message = result['message'] as String? ?? '';

      if (isMatch) {
        setState(() {
          _formUnlocked = true;
          _isVerifying = false;
          _matchedStop = session.currentStop;
        });
      } else {
        setState(() {
          _isVerifying = false;
          _verifyError = message.isNotEmpty ? message : 'Barcode did not match the expected stop.';
        });
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _verifyError = 'Could not verify barcode: $e';
      });
    }
  }

  Future<void> _submitCollection() async {
    final session = context.read<TripSession>();
    final stop = _matchedStop ?? session.currentStop;
    if (stop == null) return;

    final clearKg = double.tryParse(_clearKgController.text) ?? 0;
    final colouredKg = double.tryParse(_colouredKgController.text) ?? 0;

    if (clearKg <= 0 && colouredKg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one quantity greater than 0.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await session.confirmCollection(
        tripStopId: stop.tripStopId,
        supplierCode: stop.supplierCode,
        clearKg: clearKg,
        colouredKg: colouredKg,
        condition: _condition,
      );

      if (!mounted) return;

      if (session.allStopsCollected) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TripReportScreen()),
        );
      } else {
        // Reset for the next stop.
        setState(() {
          _formUnlocked = false;
          _matchedStop = null;
          _verifyError = null;
          _clearKgController.clear();
          _colouredKgController.clear();
          _condition = 'Good';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collection recorded. Advancing to next stop.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TripSession>();
    final stop = _matchedStop ?? session.currentStop;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan & Collect')),
      body: stop == null
          ? const Center(child: Text('No more stops to collect.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DestinationCard(stop: stop),
                  const SizedBox(height: 16),
                  if (!_formUnlocked) _buildScanSection(stop),
                  if (_formUnlocked) _buildQuantityForm(stop),
                ],
              ),
            ),
    );
  }

  Widget _buildScanSection(TripStop stop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Scan the supplier barcode to unlock collection for ${stop.supplierName}.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (_isScanning)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 320,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onBarcodeDetected,
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton.tonal(
                        onPressed: () => setState(() => _isScanning = false),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_isVerifying)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          FilledButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Open scanner'),
            onPressed: () => setState(() => _isScanning = true),
          ),
        if (_verifyError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_verifyError!, style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuantityForm(TripStop stop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 18),
              SizedBox(width: 8),
              Text('Barcode matched — form unlocked', style: TextStyle(color: Colors.green)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _clearKgController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Clear glass (kg)',
            border: const OutlineInputBorder(),
            helperText: 'Expected: ${stop.expectedClearKg.toStringAsFixed(0)} kg',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _colouredKgController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Coloured glass (kg)',
            border: const OutlineInputBorder(),
            helperText: 'Expected: ${stop.expectedColouredKg.toStringAsFixed(0)} kg',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _condition,
          decoration: const InputDecoration(labelText: 'Condition', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'Good', child: Text('Good')),
            DropdownMenuItem(value: 'Contaminated', child: Text('Contaminated')),
            DropdownMenuItem(value: 'Damaged', child: Text('Damaged')),
          ],
          onChanged: (v) => setState(() => _condition = v ?? 'Good'),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: Text(_isSubmitting ? 'Saving...' : 'Confirm collection'),
          onPressed: _isSubmitting ? null : _submitCollection,
        ),
      ],
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final TripStop stop;
  const _DestinationCard({required this.stop});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text('${stop.sequenceNumber}', style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stop.supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(stop.address, style: TextStyle(color: Colors.grey[700])),
                  Text('Supplier code: ${stop.supplierCode}', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
