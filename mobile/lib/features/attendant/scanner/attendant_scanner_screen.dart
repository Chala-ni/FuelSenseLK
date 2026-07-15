import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/api/api_client.dart';
import '../../../services/attendant_repository.dart';

class AttendantScannerScreen extends StatefulWidget {
  const AttendantScannerScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AttendantScannerScreen> createState() => _AttendantScannerScreenState();
}

class _AttendantScannerScreenState extends State<AttendantScannerScreen> {
  late final DispenseRepository _dispense = DispenseRepository(widget.api);
  final _litres = TextEditingController(text: '10');
  String _fuelType = 'petrol_92';
  String? _qrId;
  Map<String, dynamic>? _vehicle;
  Map<String, dynamic>? _quotaBlock;
  bool _scanning = true;

  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || !_scanning) return;
    setState(() {
      _scanning = false;
      _qrId = parseQrPayload(raw);
    });
    _validate();
  }

  String parseQrPayload(String raw) {
    if (raw.startsWith('fuelsense:vehicle:')) return raw.split(':').last;
    return raw;
  }

  Future<void> _validate() async {
    if (_qrId == null) return;
    try {
      final result = await _dispense.validate(
        qrId: _qrId!,
        fuelType: _fuelType,
        litres: double.parse(_litres.text),
      );
      setState(() {
        _vehicle = result['vehicle'] as Map<String, dynamic>?;
        _quotaBlock = result['valid'] == false ? result : null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        setState(() => _scanning = true);
      }
    }
  }

  Future<void> _confirm() async {
    if (_qrId == null) return;
    try {
      final receipt = await _dispense.dispense(
        qrId: _qrId!,
        fuelType: _fuelType,
        litres: double.parse(_litres.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispensed ${receipt['litres']}L — ${receipt['vehicle_plate']}')),
      );
      setState(() {
        _scanning = true;
        _qrId = null;
        _vehicle = null;
        _quotaBlock = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_quotaBlock != null) {
      final q = _quotaBlock!['quota'] as Map<String, dynamic>? ?? {};
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: FsCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.block_rounded, size: 40, color: AppColors.danger),
                  ),
                  const SizedBox(height: 20),
                  Text('Crisis Quota Blocked', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Remaining quota: ${q['remaining_litres'] ?? 0} L', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: () => setState(() { _quotaBlock = null; _scanning = true; }), child: const Text('Back to Scanner')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          const FsPageHeader(title: 'Scan & Dispense', subtitle: 'Scan driver QR code to validate fuel request'),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _scanning
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(onDetect: _onDetect),
                          Center(
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.amber400, width: 2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      )
                    : FsCard(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
                            const SizedBox(height: 12),
                            Text('Vehicle Verified', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(
                              _vehicle?['plate_number'] as String? ?? _qrId ?? '',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 2),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: FsCard(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _fuelType,
                    decoration: const InputDecoration(labelText: 'Fuel type'),
                    items: const [
                      DropdownMenuItem(value: 'petrol_92', child: Text('Petrol 92')),
                      DropdownMenuItem(value: 'petrol_95', child: Text('Petrol 95')),
                      DropdownMenuItem(value: 'auto_diesel', child: Text('Auto Diesel')),
                      DropdownMenuItem(value: 'super_diesel', child: Text('Super Diesel')),
                    ],
                    onChanged: (v) => setState(() => _fuelType = v ?? 'petrol_92'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _litres,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Litres', prefixIcon: Icon(Icons.water_drop_outlined)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => setState(() => _scanning = true), child: const Text('Rescan'))),
                      const SizedBox(width: 12),
                      Expanded(child: FilledButton(onPressed: _qrId == null ? null : _confirm, child: const Text('Confirm'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
