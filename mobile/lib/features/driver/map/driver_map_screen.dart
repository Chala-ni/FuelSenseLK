import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/repositories.dart';

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  late final StationRepository _repo = StationRepository(widget.api);
  final _mapController = MapController();
  List<Station> _stations = [];
  LatLng _center = const LatLng(6.9271, 79.8612);
  String _fuelType = 'petrol_92';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition();
        _center = LatLng(pos.latitude, pos.longitude);
      }
      _stations = await _repo.nearby(lat: _center.latitude, lng: _center.longitude, fuelType: _fuelType);
      _mapController.move(_center, 12);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          FsPageHeader(
            title: 'Fuel Map',
            subtitle: '${_stations.length} stations nearby',
            trailing: IconButton.filledTonal(
              onPressed: _load,
              icon: const Icon(Icons.my_location_rounded),
              style: IconButton.styleFrom(backgroundColor: AppColors.surfaceMuted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final ft in ['petrol_92', 'petrol_95', 'auto_diesel', 'super_diesel'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(fuelLabel(ft)),
                        selected: _fuelType == ft,
                        onSelected: (_) {
                          setState(() => _fuelType = ft);
                          _load();
                        },
                        selectedColor: AppColors.fuelColor(ft).withValues(alpha: 0.15),
                        checkmarkColor: AppColors.fuelColor(ft),
                        labelStyle: TextStyle(
                          color: _fuelType == ft ? AppColors.fuelColor(ft) : AppColors.textSecondary,
                          fontWeight: _fuelType == ft ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(initialCenter: _center, initialZoom: 12),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'lk.fuelsense.app'),
                        MarkerLayer(
                          markers: [
                            for (final s in _stations)
                              Marker(
                                point: LatLng(s.latitude, s.longitude),
                                width: 44,
                                height: 44,
                                child: GestureDetector(
                                  onTap: () => _showDetail(s),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: stockPinColor(s.stockPct(_fuelType)),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(color: stockPinColor(s.stockPct(_fuelType)).withValues(alpha: 0.4), blurRadius: 8),
                                      ],
                                    ),
                                    child: const Icon(Icons.local_gas_station, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
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

  void _showDetail(Station station) {
    final pct = station.stockPct(_fuelType);
    final color = stockPinColor(pct);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.local_gas_station_rounded, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(station.name, style: Theme.of(ctx).textTheme.titleLarge),
                        Text('${station.distanceKm?.toStringAsFixed(1) ?? '?'} km away', style: Theme.of(ctx).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (pct != null)
                FsStockGauge(fuelType: _fuelType, percentage: pct, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
