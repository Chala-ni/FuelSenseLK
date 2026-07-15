import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/attendant_repository.dart';

class AttendantDeliveryScreen extends StatefulWidget {
  const AttendantDeliveryScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AttendantDeliveryScreen> createState() => _AttendantDeliveryScreenState();
}

class _AttendantDeliveryScreenState extends State<AttendantDeliveryScreen> {
  late final DispenseRepository _repo = DispenseRepository(widget.api);
  final _litres = TextEditingController();
  String _fuelType = 'petrol_92';
  List<Map<String, dynamic>> _history = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _repo.deliveryHistory();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await _repo.logDelivery(fuelType: _fuelType, litres: double.parse(_litres.text));
      _litres.clear();
      await _loadHistory();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery logged successfully')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FsPageHeader(title: 'Delivery Log', subtitle: 'Record incoming fuel tanker deliveries'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    decoration: const InputDecoration(
                      labelText: 'Litres delivered',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add_rounded),
                      label: const Text('Log Delivery'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Recent Deliveries', style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _history.isEmpty
                ? const FsEmptyState(icon: Icons.inventory_2_outlined, title: 'No deliveries logged yet')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _history.length,
                    itemBuilder: (_, i) {
                      final d = _history[i];
                      final ft = d['fuel_type'] as String;
                      return FsListTileCard(
                        title: '${d['litres']} L · ${fuelLabel(ft)}',
                        subtitle: '${d['delivered_at']}'.substring(0, 16),
                        accentColor: AppColors.teal500,
                        leading: const Icon(Icons.local_shipping_rounded, color: AppColors.teal500, size: 20),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
