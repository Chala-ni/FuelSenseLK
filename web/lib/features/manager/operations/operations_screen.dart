import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/shell_scaffold.dart';
import '../../../services/repositories.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late final _ops = OperationsRepository(widget.api);

  List<Map<String, dynamic>> _dispenses = [];
  List<Map<String, dynamic>> _deliveries = [];
  List<String> _fuelTypes = ['petrol_92'];
  bool _loading = true;
  String? _error;

  final _deliveryFuel = ValueNotifier<String>('petrol_92');
  final _litres = TextEditingController();
  final _notes = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _litres.dispose();
    _notes.dispose();
    _deliveryFuel.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await widget.api.me();
      final station = me?['station'] as int?;
      final results = await Future.wait([
        _ops.dispenseHistory(),
        _ops.deliveryHistory(),
      ]);
      final stationDetail = station != null ? await StationRepository(widget.api).detail(station) : null;
      if (!mounted) return;
      setState(() {
        _dispenses = results[0] as List<Map<String, dynamic>>;
        _deliveries = results[1] as List<Map<String, dynamic>>;
        if (stationDetail != null) {
          _fuelTypes = List<String>.from(stationDetail['fuel_types'] as List? ?? ['petrol_92']);
          _deliveryFuel.value = _fuelTypes.first;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logDelivery() async {
    final litres = double.tryParse(_litres.text.trim());
    if (litres == null || litres <= 0) {
      _showSnack('Enter a valid litre amount', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await _ops.logDelivery(
        fuelType: _deliveryFuel.value,
        litres: litres,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      _litres.clear();
      _notes.clear();
      await _load();
      if (mounted) _showSnack('Delivery logged successfully');
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FsPageHeader(
            title: 'Operations',
            subtitle: 'Dispense logs & fuel deliveries',
            trailing: IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _load),
          ),
          Container(
            color: AppColors.surfaceCard,
            child: TabBar(
          controller: _tabs,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: AppColors.borderFaint,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
          tabs: const [Tab(text: 'Dispense history'), Tab(text: 'Deliveries')],
            ),
          ),
          Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? FsEmptyState(icon: Icons.error_outline, title: 'Failed to load', subtitle: _error, action: FilledButton(onPressed: _load, child: const Text('Retry')), compact: true)
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _DispenseTab(records: _dispenses),
                        _DeliveryTab(
                          records: _deliveries,
                          fuelTypes: _fuelTypes,
                          fuelNotifier: _deliveryFuel,
                          litres: _litres,
                          notes: _notes,
                          submitting: _submitting,
                          onSubmit: _logDelivery,
                        ),
                      ],
                    ),
        ),
      ],
      ),
    );
  }
}

class _DispenseTab extends StatelessWidget {
  const _DispenseTab({required this.records});

  final List<Map<String, dynamic>> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const FsEmptyState(icon: Icons.receipt_long_outlined, title: 'No dispense records');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageX, 8, AppSpacing.pageX, AppSpacing.pageY),
      itemCount: records.length,
      itemBuilder: (context, i) {
        final r = records[i];
        final ft = r['fuel_type'] as String;
        final price = parseApiDouble(r['price_per_litre']);
        final litres = parseApiDouble(r['litres']);
        final total = price != null && litres != null ? price * litres : null;
        return FsListTileCard(
          title: '${r['vehicle_plate'] ?? 'Vehicle'} · ${fuelLabel(ft)}',
          subtitle: '${formatLitres(litres)} · ${formatDateTime(r['dispensed_at'])}${total != null ? ' · ${formatCurrency(total)}' : ''}',
          accentColor: AppColors.fuelColor(ft),
          leading: Icon(fuelIcon(ft), color: AppColors.fuelColor(ft), size: 20),
        );
      },
    );
  }
}

class _DeliveryTab extends StatelessWidget {
  const _DeliveryTab({
    required this.records,
    required this.fuelTypes,
    required this.fuelNotifier,
    required this.litres,
    required this.notes,
    required this.submitting,
    required this.onSubmit,
  });

  final List<Map<String, dynamic>> records;
  final List<String> fuelTypes;
  final ValueNotifier<String> fuelNotifier;
  final TextEditingController litres;
  final TextEditingController notes;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageX, 8, AppSpacing.pageX, AppSpacing.pageY),
      children: [
        FsPanel(
          header: const FsPanelHeader(title: 'Log Delivery', subtitle: 'Record incoming fuel delivery'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: fuelNotifier,
                    builder: (context, fuel, _) => DropdownButtonFormField<String>(
                      value: fuel,
                      decoration: const InputDecoration(labelText: 'Fuel type'),
                      items: [
                        for (final ft in fuelTypes)
                          DropdownMenuItem(value: ft, child: Text(fuelLabel(ft))),
                      ],
                      onChanged: (v) {
                        if (v != null) fuelNotifier.value = v;
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: litres,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Litres', suffixText: 'L'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: notes,
                    decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: submitting ? null : onSubmit,
                  icon: submitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Log'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        FsPanel(
          header: const FsPanelHeader(title: 'Delivery History'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPad),
            child: records.isEmpty
                ? const FsEmptyState(icon: Icons.local_shipping_outlined, title: 'No deliveries logged', compact: true)
                : Column(
                    children: [
                      for (final d in records)
                        Builder(builder: (context) {
                          final ft = d['fuel_type'] as String;
                          return FsListTileCard(
                            title: '${formatLitres(parseApiDouble(d['litres']))} · ${fuelLabel(ft)}',
                            subtitle: formatDateTime(d['delivered_at']),
                            accentColor: AppColors.fuelColor(ft),
                            leading: const Icon(Icons.local_shipping_rounded, color: AppColors.teal500, size: 20),
                          );
                        }),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
