import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../services/repositories.dart';

class AdminDeliveriesTab extends StatefulWidget {
  const AdminDeliveriesTab({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminDeliveriesTab> createState() => _AdminDeliveriesTabState();
}

class _AdminDeliveriesTabState extends State<AdminDeliveriesTab> {
  late final _ops = OperationsRepository(widget.api);
  late final _stationRepo = StationRepository(widget.api);

  List<Map<String, dynamic>> _deliveries = [];
  List<Map<String, dynamic>> _stationList = [];
  int? _stationFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        _ops.deliveryHistory(stationId: _stationFilter),
        _stationRepo.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _deliveries = results[0];
        _stationList = results[1];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.pageX, 8, AppSpacing.pageX, AppSpacing.pageY),
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: _stationFilter,
                decoration: const InputDecoration(labelText: 'Filter by station'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All stations')),
                  for (final s in _stationList)
                    DropdownMenuItem(value: s['id'] as int, child: Text(s['name'] as String)),
                ],
                onChanged: (v) async {
                  setState(() => _stationFilter = v);
                  await _load();
                },
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        const SizedBox(height: 20),
        const FsSectionHeader(title: 'Network Delivery Log', subtitle: 'Cross-station delivery history'),
        if (_deliveries.isEmpty)
          const FsEmptyState(icon: Icons.local_shipping_outlined, title: 'No deliveries found')
        else
          FsCard(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Station')),
                  DataColumn(label: Text('Fuel')),
                  DataColumn(label: Text('Litres')),
                  DataColumn(label: Text('Delivered')),
                  DataColumn(label: Text('Notes')),
                ],
                rows: [
                  for (final d in _deliveries.take(100))
                    DataRow(cells: [
                      DataCell(Text(d['station_name'] as String? ?? '#${d['station']}')),
                      DataCell(Text(fuelLabel(d['fuel_type'] as String))),
                      DataCell(Text(formatLitres(parseApiDouble(d['litres'])))),
                      DataCell(Text(formatDateTime(d['delivered_at']))),
                      DataCell(Text((d['notes'] as String?) ?? '—', style: const TextStyle(fontSize: 12))),
                    ]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
