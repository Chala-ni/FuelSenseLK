import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../../services/repositories.dart';

class VehicleQrScreen extends StatefulWidget {
  const VehicleQrScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<VehicleQrScreen> createState() => _VehicleQrScreenState();
}

class _VehicleQrScreenState extends State<VehicleQrScreen> {
  late final VehicleRepository _repo = VehicleRepository(widget.api);
  List<Vehicle> _vehicles = [];
  Vehicle? _selected;
  String _qrPayload = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.list();
    setState(() {
      _vehicles = list;
      _selected = list.isNotEmpty ? list.first : null;
    });
    if (_selected != null) _loadQr(_selected!.id);
  }

  Future<void> _loadQr(int id) async {
    final data = await _repo.qrPayload(id);
    setState(() => _qrPayload = data['qr_payload'] as String? ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selected == null
          ? const FsEmptyState(
              icon: Icons.directions_car_outlined,
              title: 'No vehicles registered',
              subtitle: 'Add a vehicle from your profile to generate a QR code',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const FsPageHeader(
                    title: 'Dispense QR',
                    subtitle: 'Show this code at the station pump',
                  ),
                  FsCard(
                    child: Column(
                      children: [
                        DropdownButtonFormField<Vehicle>(
                          value: _selected,
                          decoration: const InputDecoration(labelText: 'Select vehicle'),
                          items: _vehicles.map((v) => DropdownMenuItem(value: v, child: Text(v.plateNumber))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selected = v);
                              _loadQr(v.id);
                            }
                          },
                        ),
                        const SizedBox(height: 28),
                        if (_qrPayload.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: QrImageView(
                              data: _qrPayload,
                              size: 220,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.navy800),
                              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.navy800),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          _selected!.plateNumber,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 2),
                        ),
                        Text(_selected!.vehicleType, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
