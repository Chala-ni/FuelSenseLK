import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/repositories.dart';

class SmartFinderScreen extends StatefulWidget {
  const SmartFinderScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<SmartFinderScreen> createState() => _SmartFinderScreenState();
}

class _SmartFinderScreenState extends State<SmartFinderScreen> {
  late final StationRepository _repo = StationRepository(widget.api);
  double _radius = 10;
  double _minStock = 20;
  String _fuelType = 'petrol_92';
  List<Station> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final pos = await Geolocator.getCurrentPosition();
      final list = await _repo.nearby(
        lat: pos.latitude,
        lng: pos.longitude,
        radiusKm: _radius,
        fuelType: _fuelType,
        minStock: _minStock,
      );
      setState(() => _results = list.take(5).toList());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FsPageHeader(title: 'Smart Finder', subtitle: 'Find stations with available fuel'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                FsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Search radius', style: Theme.of(context).textTheme.titleMedium),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _radius,
                              min: 5,
                              max: 30,
                              divisions: 5,
                              activeColor: AppColors.amber500,
                              onChanged: (v) => setState(() => _radius = v),
                            ),
                          ),
                          Text('${_radius.toStringAsFixed(0)} km', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Minimum stock', style: Theme.of(context).textTheme.titleMedium),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _minStock,
                              min: 0,
                              max: 80,
                              divisions: 8,
                              activeColor: AppColors.teal500,
                              onChanged: (v) => setState(() => _minStock = v),
                            ),
                          ),
                          Text('${_minStock.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final ft in ['petrol_92', 'petrol_95', 'auto_diesel'])
                            ChoiceChip(
                              label: Text(fuelLabel(ft)),
                              selected: _fuelType == ft,
                              onSelected: (_) => setState(() => _fuelType = ft),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _search,
                          icon: _loading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.search_rounded),
                          label: const Text('Search Stations'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_results.isEmpty && !_loading)
                  const FsEmptyState(icon: Icons.search_off_rounded, title: 'No results yet', subtitle: 'Adjust filters and search')
                else
                  ..._results.map((s) {
                    final pct = s.stockPct(_fuelType);
                    final color = stockPinColor(pct);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FsListTileCard(
                        title: s.name,
                        subtitle: '${s.distanceKm?.toStringAsFixed(1)} km · ${pct?.toStringAsFixed(0) ?? '?'}% ${fuelLabel(_fuelType)}',
                        accentColor: AppColors.fuelColor(_fuelType),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${pct?.toStringAsFixed(0) ?? '?'}%', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                        ),
                        leading: Icon(Icons.local_gas_station_rounded, color: AppColors.fuelColor(_fuelType)),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
