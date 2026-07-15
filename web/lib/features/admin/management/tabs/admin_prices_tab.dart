import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../services/repositories.dart';

class AdminPricesTab extends StatefulWidget {
  const AdminPricesTab({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminPricesTab> createState() => _AdminPricesTabState();
}

class _AdminPricesTabState extends State<AdminPricesTab> {
  late final _prices = PriceRepository(widget.api);
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _submitting = false;

  String _fuelType = 'petrol_92';
  final _price = TextEditingController();
  final _source = TextEditingController(text: 'CPC');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _price.dispose();
    _source.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final history = await _prices.history();
      if (mounted) setState(() => _history = history);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final p = double.tryParse(_price.text.trim());
    if (p == null || p <= 0) {
      _snack('Enter a valid price', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await _prices.create(fuelType: _fuelType, pricePerLitre: p, source: _source.text.trim());
      _price.clear();
      await _load();
      _snack('Price recorded');
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.pageX, 8, AppSpacing.pageX, AppSpacing.pageY),
      children: [
        FsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FsSectionHeader(title: 'Log Price Change', subtitle: 'National fuel price update'),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _fuelType,
                      decoration: const InputDecoration(labelText: 'Fuel type'),
                      items: const [
                        DropdownMenuItem(value: 'petrol_92', child: Text('Petrol 92')),
                        DropdownMenuItem(value: 'petrol_95', child: Text('Petrol 95')),
                        DropdownMenuItem(value: 'auto_diesel', child: Text('Auto Diesel')),
                        DropdownMenuItem(value: 'super_diesel', child: Text('Super Diesel')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _fuelType = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price per litre', prefixText: 'Rs '),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _source,
                      decoration: const InputDecoration(labelText: 'Source'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _submitting ? null : _create,
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Record'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const FsSectionHeader(title: 'Price History'),
        if (_history.isEmpty)
          const FsEmptyState(icon: Icons.price_change_outlined, title: 'No price records')
        else
          ..._history.take(30).map((p) {
            return FsListTileCard(
              title: '${fuelLabel(p['fuel_type'] as String)} · ${formatCurrency(parseApiDouble(p['price_per_litre']))}',
              subtitle: '${formatDateTime(p['effective_from'])} · ${p['source'] ?? '—'}',
              accentColor: AppColors.fuelColor(p['fuel_type'] as String),
            );
          }),
      ],
    );
  }
}
