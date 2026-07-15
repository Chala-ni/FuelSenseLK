import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/shell_scaffold.dart';
import '../../../services/repositories.dart';

class ManagerStaffScreen extends StatefulWidget {
  const ManagerStaffScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ManagerStaffScreen> createState() => _ManagerStaffScreenState();
}

class _ManagerStaffScreenState extends State<ManagerStaffScreen> {
  List<Map<String, dynamic>> _staff = [];
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = true;
  bool _adding = false;
  String? _error;
  int? _stationId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await widget.api.me();
      _stationId = me?['station'] as int?;
      final res = await widget.api.get('/auth/users/');
      if (res.statusCode != 200) throw ApiException(parseApiError(res.body), res.statusCode);
      if (!mounted) return;
      setState(() => _staff = List<Map<String, dynamic>>.from(jsonDecode(res.body) as List));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_stationId == null) {
      _showSnack('No station assigned to your account', isError: true);
      return;
    }
    if (_email.text.trim().isEmpty || _password.text.length < 8) {
      _showSnack('Enter a valid email and password (min 8 chars)', isError: true);
      return;
    }
    setState(() => _adding = true);
    try {
      final res = await widget.api.post('/auth/users/', {
        'email': _email.text.trim(),
        'username': _email.text.trim().split('@').first,
        'password': _password.text,
        'role': 'attendant',
        'station': _stationId,
      });
      if (res.statusCode == 201) {
        _email.clear();
        _password.clear();
        await _load();
        if (mounted) _showSnack('Attendant added');
      } else {
        _showSnack(parseApiError(res.body), isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _setActive(int id, bool active) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Deactivate attendant?'),
          content: const Text('They will no longer be able to sign in.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.danger), onPressed: () => Navigator.pop(ctx, true), child: const Text('Deactivate')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      final res = await widget.api.patch('/auth/users/$id/', {'is_active': active});
      if (res.statusCode == 200) {
        await _load();
        if (mounted) _showSnack(active ? 'Reactivated' : 'Deactivated');
      } else {
        _showSnack(parseApiError(res.body), isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? AppColors.danger : null),
    );
  }

  void _generatePassword() {
    final base = DateTime.now().millisecondsSinceEpoch.toString();
    _password.text = 'Fs${base.substring(base.length - 6)}!';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final active = _staff.where((u) => u['is_active'] == true).length;

    return DashboardPage(
      title: 'Station Staff',
      subtitle: '$active active · ${_staff.length} total',
      trailing: IconButton(
        icon: const Icon(Icons.refresh_rounded, size: 20),
        onPressed: _load,
        visualDensity: VisualDensity.compact,
      ),
      child: _loading
          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.itemGap),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ),
                FsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FsSectionHeader(title: 'Add attendant', subtitle: 'Create a new station attendant account'),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 280,
                            child: TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined, size: 18)),
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _password,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Temp password',
                                suffixIcon: IconButton(icon: const Icon(Icons.autorenew_rounded, size: 18), onPressed: _generatePassword),
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _adding ? null : _create,
                            icon: _adding
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                FsPanel(
                  header: Text('Team members (${_staff.length})', style: Theme.of(context).textTheme.titleLarge),
                  child: _staff.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpacing.cardPad),
                          child: FsEmptyState(icon: Icons.people_outline, title: 'No staff yet', compact: true),
                        )
                      : Column(
                          children: [
                            for (final user in _staff) _StaffRow(user: user, onToggle: _setActive),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.user, required this.onToggle});

  final Map<String, dynamic> user;
  final void Function(int id, bool active) onToggle;

  @override
  Widget build(BuildContext context) {
    final isActive = user['is_active'] as bool? ?? false;
    final email = user['email'] as String;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isActive ? AppColors.successSoft : AppColors.surfaceMuted,
        child: Text(email[0].toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isActive ? AppColors.success : AppColors.textMuted)),
      ),
      title: Text(email, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text('${formatRole(user['role'] as String? ?? '')} · ${isActive ? 'Active' : 'Inactive'}', style: const TextStyle(fontSize: 11)),
      trailing: isActive
          ? IconButton(icon: const Icon(Icons.person_off_outlined, size: 18, color: AppColors.danger), onPressed: () => onToggle(user['id'] as int, false))
          : TextButton(onPressed: () => onToggle(user['id'] as int, true), child: const Text('Reactivate')),
    );
  }
}
