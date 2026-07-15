import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../../services/repositories.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<VehicleManagementScreen> createState() => _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  late final VehicleRepository _repo = VehicleRepository(widget.api);
  List<Vehicle> _vehicles = [];
  final _plate = TextEditingController();
  String _type = 'car';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final vehicles = await _repo.list();
    if (mounted) setState(() => _vehicles = vehicles);
  }

  Future<void> _add() async {
    await _repo.create(_plate.text.trim(), _type);
    _plate.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Vehicles'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: FsCard(
              child: Column(
                children: [
                  TextField(
                    controller: _plate,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Plate number',
                      prefixIcon: Icon(Icons.pin_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Vehicle type'),
                    items: const [
                      DropdownMenuItem(value: 'motorcycle', child: Text('Motorcycle')),
                      DropdownMenuItem(value: 'car', child: Text('Car')),
                      DropdownMenuItem(value: 'van', child: Text('Van')),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? 'car'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Register Vehicle'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _vehicles.isEmpty
                ? const FsEmptyState(icon: Icons.directions_car_outlined, title: 'No vehicles yet')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _vehicles.length,
                    itemBuilder: (_, i) {
                      final v = _vehicles[i];
                      return FsListTileCard(
                        title: v.plateNumber,
                        subtitle: v.vehicleType,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.infoSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.directions_car_rounded, color: AppColors.info, size: 20),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                          onPressed: () async {
                            await _repo.deactivate(v.id);
                            _load();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
