import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/shell_scaffold.dart';
import '../../../services/repositories.dart';

class AdminCrisisScreen extends StatefulWidget {
  const AdminCrisisScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminCrisisScreen> createState() => _AdminCrisisScreenState();
}

class _AdminCrisisScreenState extends State<AdminCrisisScreen> {
  late final _crisisRepo = CrisisRepository(widget.api);

  Map<String, dynamic>? _status;
  bool _loading = true;
  bool _submitting = false;
  final _message = TextEditingController();

  final _quotaRows = <_QuotaRow>[];

  @override
  void initState() {
    super.initState();
    _quotaRows.add(_QuotaRow());
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    for (final r in _quotaRows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = await _crisisRepo.status();
      if (mounted) setState(() => _status = status);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activate() async {
    setState(() => _submitting = true);
    try {
      final quotas = <Map<String, dynamic>>[];
      for (final row in _quotaRows) {
        final maxL = double.tryParse(row.maxLitres.text.trim());
        final cooldown = int.tryParse(row.cooldown.text.trim());
        if (maxL == null) continue;
        quotas.add({
          'vehicle_type': row.vehicleType,
          'fuel_type': row.fuelType,
          'max_litres': maxL,
          'cooldown_hours': cooldown ?? 24,
        });
      }
      await _crisisRepo.activate(message: _message.text.trim(), quotas: quotas.isEmpty ? null : quotas);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Crisis mode activated')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate crisis mode?'),
        content: const Text('National dispensing quotas will be lifted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      await _crisisRepo.deactivate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Crisis mode deactivated')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final active = _status?['is_active'] == true;
    final quotas = (_status?['quotas'] as List?) ?? [];

    return DashboardPage(
      title: 'Crisis Management',
      subtitle: 'National fuel rationing & dispensing quotas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FsCard(
            child: Row(
              children: [
                Icon(
                  active ? Icons.emergency_rounded : Icons.shield_outlined,
                  color: active ? AppColors.danger : AppColors.success,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active ? 'Crisis mode is ACTIVE' : 'Crisis mode is off',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: active ? AppColors.danger : AppColors.success,
                            ),
                      ),
                      if (active && (_status?['message'] as String?)?.isNotEmpty == true)
                        Text(_status!['message'] as String),
                      if (active && _status?['activated_at'] != null)
                        Text('Since ${formatDateTime(_status!['activated_at'])}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (active)
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                    onPressed: _submitting ? null : _deactivate,
                    child: const Text('Deactivate'),
                  ),
              ],
            ),
          ),
          if (active && quotas.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            const FsSectionHeader(title: 'Active Quotas'),
            ...quotas.map((q) {
              final m = q as Map<String, dynamic>;
              return FsListTileCard(
                title: '${m['vehicle_type']} · ${fuelLabel(m['fuel_type'] as String)}',
                subtitle: 'Max ${m['max_litres']} L · ${m['cooldown_hours']}h cooldown',
                leading: const Icon(Icons.gas_meter_outlined, color: AppColors.danger),
              );
            }),
          ],
          if (!active) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            FsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FsSectionHeader(title: 'Activate Crisis Mode', subtitle: 'Set a public message and optional dispensing quotas'),
                  TextField(
                    controller: _message,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Public message',
                      hintText: 'e.g. National fuel shortage — rationing in effect',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const FsSectionHeader(title: 'Quota Rules'),
                  ..._quotaRows.map((row) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: row.build(onRemove: _quotaRows.length > 1 ? () => setState(() => _quotaRows.remove(row)) : null),
                      )),
                  TextButton.icon(
                    onPressed: () => setState(() => _quotaRows.add(_QuotaRow())),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add quota rule'),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                      onPressed: _submitting ? null : _activate,
                      icon: _submitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.emergency_rounded),
                      label: const Text('Activate crisis mode'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuotaRow {
  _QuotaRow();

  String vehicleType = 'car';
  String fuelType = 'petrol_92';
  final maxLitres = TextEditingController(text: '20');
  final cooldown = TextEditingController(text: '24');

  void dispose() {
    maxLitres.dispose();
    cooldown.dispose();
  }

  Widget build({VoidCallback? onRemove}) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: vehicleType,
            decoration: const InputDecoration(labelText: 'Vehicle'),
            items: const [
              DropdownMenuItem(value: 'motorcycle', child: Text('Motorcycle')),
              DropdownMenuItem(value: 'three_wheeler', child: Text('Three Wheeler')),
              DropdownMenuItem(value: 'car', child: Text('Car')),
              DropdownMenuItem(value: 'van', child: Text('Van')),
              DropdownMenuItem(value: 'lorry', child: Text('Lorry')),
            ],
            onChanged: (v) {
              if (v != null) vehicleType = v;
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: fuelType,
            decoration: const InputDecoration(labelText: 'Fuel'),
            items: const [
              DropdownMenuItem(value: 'petrol_92', child: Text('Petrol 92')),
              DropdownMenuItem(value: 'petrol_95', child: Text('Petrol 95')),
              DropdownMenuItem(value: 'auto_diesel', child: Text('Auto Diesel')),
              DropdownMenuItem(value: 'super_diesel', child: Text('Super Diesel')),
            ],
            onChanged: (v) {
              if (v != null) fuelType = v;
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: maxLitres,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Max L'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: cooldown,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cooldown h'),
          ),
        ),
        if (onRemove != null)
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: onRemove),
      ],
    );
  }
}
