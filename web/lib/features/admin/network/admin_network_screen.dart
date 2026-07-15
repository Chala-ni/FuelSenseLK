import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/repositories.dart';

class AdminNetworkScreen extends StatefulWidget {
  const AdminNetworkScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminNetworkScreen> createState() => _AdminNetworkScreenState();
}

class _AdminNetworkScreenState extends State<AdminNetworkScreen> {
  final _mapController = MapController();
  late final _stations = StationRepository(widget.api);

  List<Map<String, dynamic>> _all = [];
  Map<String, dynamic>? _selected;
  String? _district;
  String _fuelType = 'petrol_92';
  double _minStock = 0;
  bool _loading = true;
  String? _error;
  bool _mapReady = false;
  LatLng? _pendingCenter;
  double _pendingZoom = 7.5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _applyMapView() {
    if (!_mapReady || _pendingCenter == null) return;
    _mapController.move(_pendingCenter!, _pendingZoom);
  }

  void _setMapViewFromStations(List<Map<String, dynamic>> stations) {
    if (stations.isEmpty) return;
    final lats = stations.map((s) => parseApiDouble(s['latitude']) ?? 0).toList();
    final lngs = stations.map((s) => parseApiDouble(s['longitude']) ?? 0).toList();
    _pendingCenter = LatLng(
      lats.reduce((a, b) => a + b) / lats.length,
      lngs.reduce((a, b) => a + b) / lngs.length,
    );
    _pendingZoom = 8;
    _applyMapView();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stations = await _stations.list(district: _district, fuelType: _fuelType);
      if (!mounted) return;
      setState(() => _all = stations);
      _setMapViewFromStations(stations);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_minStock <= 0) return _all;
    return _all.where((s) {
      final stocks = s['stock_levels'] as List? ?? [];
      for (final raw in stocks) {
        final st = raw as Map<String, dynamic>;
        if (st['fuel_type'] == _fuelType) {
          return double.parse(st['percentage'].toString()) >= _minStock;
        }
      }
      return false;
    }).toList();
  }

  List<String> get _districts {
    final set = <String>{};
    for (final s in _all) {
      final d = s['district'] as String?;
      if (d != null && d.isNotEmpty) set.add(d);
    }
    return set.toList()..sort();
  }

  double? _stockPct(Map<String, dynamic> station) {
    final stocks = station['stock_levels'] as List? ?? [];
    for (final raw in stocks) {
      final st = raw as Map<String, dynamic>;
      if (st['fuel_type'] == _fuelType) return double.parse(st['percentage'].toString());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final stations = _filtered;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.pageX, 12, AppSpacing.pageX, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('National Network', style: Theme.of(context).textTheme.headlineMedium),
                    Text('${stations.length} stations · live stock map', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final ft in ['petrol_92', 'petrol_95', 'auto_diesel', 'super_diesel'])
                      FilterChip(
                        label: Text(fuelLabel(ft)),
                        selected: _fuelType == ft,
                        onSelected: (_) {
                          setState(() => _fuelType = ft);
                          _load();
                        },
                      ),
                    DropdownButton<String?>(
                      value: _district,
                      hint: const Text('All districts'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All districts')),
                        for (final d in _districts) DropdownMenuItem(value: d, child: Text(d)),
                      ],
                      onChanged: (v) {
                        setState(() => _district = v);
                        _load();
                      },
                    ),
                    SizedBox(
                      width: 180,
                      child: Row(
                        children: [
                          const Text('Min stock', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: _minStock,
                              max: 75,
                              divisions: 15,
                              label: '${_minStock.toInt()}%',
                              onChanged: (v) => setState(() => _minStock = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      style: IconButton.styleFrom(backgroundColor: AppColors.surfaceMuted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? FsEmptyState(
                              icon: Icons.error_outline,
                              title: 'Failed to load',
                              subtitle: _error,
                              action: FilledButton(onPressed: _load, child: const Text('Retry')),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _pendingCenter ?? const LatLng(7.8731, 80.7718),
                                  initialZoom: _pendingZoom,
                                  onMapReady: () {
                                    _mapReady = true;
                                    _applyMapView();
                                  },
                                  onTap: (_, __) => setState(() => _selected = null),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'lk.fuelsense.web',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      for (final s in stations)
                                        Marker(
                                          point: LatLng(
                                            parseApiDouble(s['latitude']) ?? 0,
                                            parseApiDouble(s['longitude']) ?? 0,
                                          ),
                                          width: 36,
                                          height: 36,
                                          child: GestureDetector(
                                            onTap: () => setState(() => _selected = s),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: stockPinColor(_stockPct(s)),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                              ),
                                              child: const Icon(Icons.local_gas_station, color: Colors.white, size: 18),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 360,
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            border: Border(left: BorderSide(color: AppColors.border)),
          ),
          child: _selected == null
              ? const FsEmptyState(
                  icon: Icons.touch_app_outlined,
                  title: 'Select a station',
                  subtitle: 'Click a map pin to view stock details',
                )
              : _StationDetailPanel(
                  key: ValueKey(_selected!['id']),
                  station: _selected!,
                  api: widget.api,
                ),
        ),
      ],
    );
  }
}

class _StationDetailPanel extends StatefulWidget {
  const _StationDetailPanel({super.key, required this.station, required this.api});

  final Map<String, dynamic> station;
  final ApiClient api;

  @override
  State<_StationDetailPanel> createState() => _StationDetailPanelState();
}

class _StationDetailPanelState extends State<_StationDetailPanel> {
  Map<String, dynamic>? _dashboard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    final id = widget.station['id'] as int;
    final res = await widget.api.get('/manager/dashboard/', query: {'station_id': id.toString()});
    if (mounted) {
      setState(() {
        _loading = false;
        if (res.statusCode == 200) {
          _dashboard = jsonDecode(res.body) as Map<String, dynamic>;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.station;
    final stocks = List<Map<String, dynamic>>.from((s['stock_levels'] as List?) ?? []);
    final risks = (_dashboard?['depletion_risks'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(s['name'] as String, style: Theme.of(context).textTheme.titleLarge),
        Text('${s['district'] ?? ''} · ${s['address'] ?? ''}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_dashboard != null) ...[
          Row(
            children: [
              Expanded(
                child: FsStatCard(
                  label: 'Dispenses',
                  value: '${_dashboard!['dispense_today']}',
                  icon: Icons.receipt,
                  iconColor: AppColors.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FsStatCard(
                  label: 'Litres',
                  value: formatLitres(parseApiDouble(_dashboard!['litres_today'])),
                  icon: Icons.water_drop,
                  iconColor: AppColors.teal500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        const FsSectionHeader(title: 'Stock Levels'),
        ...stocks.map((st) {
          final ft = st['fuel_type'] as String;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FsStockGauge(
              fuelType: ft,
              percentage: double.parse(st['percentage'].toString()),
              litres: st['current_litres']?.toString(),
            ),
          );
        }),
        const SizedBox(height: 12),
        const FsSectionHeader(title: 'Depletion Risks'),
        if (risks.isEmpty)
          const Text('No active risks', style: TextStyle(color: AppColors.textMuted))
        else
          ...risks.take(4).map((r) {
            final m = r as Map<String, dynamic>;
            return FsListTileCard(
              title: fuelLabel(m['fuel_type'] as String),
              subtitle: '${m['horizon_hours']}h · ${m['risk_tier']}',
              trailing: FsRiskBadge(tier: m['risk_tier'] as String),
            );
          }),
      ],
    );
  }
}
