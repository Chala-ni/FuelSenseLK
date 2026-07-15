import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../services/repositories.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  late final _users = UserRepository(widget.api);
  late final _stationRepo = StationRepository(widget.api);

  List<Map<String, dynamic>> _usersList = [];
  List<Map<String, dynamic>> _stationList = [];
  String? _myRole;
  bool _loading = true;
  bool _creating = false;

  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'attendant';
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
    setState(() => _loading = true);
    try {
      final me = await widget.api.me();
      final results = await Future.wait<List<Map<String, dynamic>>>([
        _users.list(),
        _stationRepo.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _myRole = me?['role'] as String?;
        _usersList = results[0];
        _stationList = results[1];
        _stationId ??= _stationList.isNotEmpty ? _stationList.first['id'] as int : null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _creatableRoles {
    if (_myRole == 'super_admin') {
      return ['driver', 'attendant', 'station_manager', 'admin', 'super_admin'];
    }
    return ['driver', 'attendant', 'station_manager', 'admin'];
  }

  Future<void> _create() async {
    if (_email.text.trim().isEmpty || _password.text.length < 8) {
      _snack('Email and password (8+ chars) required', error: true);
      return;
    }
    if ((_role == 'attendant' || _role == 'station_manager') && _stationId == null) {
      _snack('Station required for this role', error: true);
      return;
    }
    setState(() => _creating = true);
    try {
      await _users.create({
        'email': _email.text.trim(),
        'username': _email.text.trim().split('@').first,
        'password': _password.text,
        'role': _role,
        if (_stationId != null && (_role == 'attendant' || _role == 'station_manager')) 'station': _stationId,
      });
      _email.clear();
      _password.clear();
      await _load();
      _snack('User created');
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _toggleActive(int id, bool active) async {
    try {
      await _users.update(id, {'is_active': active});
      await _load();
    } catch (e) {
      _snack(e.toString(), error: true);
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
              const FsSectionHeader(title: 'Create User', subtitle: 'Assign role and station'),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      value: _role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: [
                        for (final r in _creatableRoles)
                          DropdownMenuItem(value: r, child: Text(formatRole(r))),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _role = v);
                      },
                    ),
                  ),
                  if (_role == 'attendant' || _role == 'station_manager')
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<int>(
                        value: _stationId,
                        decoration: const InputDecoration(labelText: 'Station'),
                        items: [
                          for (final s in _stationList)
                            DropdownMenuItem(value: s['id'] as int, child: Text(s['name'] as String)),
                        ],
                        onChanged: (v) => setState(() => _stationId = v),
                      ),
                    ),
                  FilledButton(
                    onPressed: _creating ? null : _create,
                    child: _creating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FsSectionHeader(title: 'All Users', subtitle: '${_usersList.length} accounts'),
        ..._usersList.map((u) {
          final active = u['is_active'] as bool? ?? false;
          final email = u['email'] as String;
          final station = u['station'];
          return FsListTileCard(
            title: email,
            subtitle: '${formatRole(u['role'] as String? ?? '')}${station != null ? ' · Station #$station' : ''} · ${active ? 'Active' : 'Inactive'}',
            leading: CircleAvatar(
              backgroundColor: active ? AppColors.teal500.withValues(alpha: 0.12) : AppColors.surfaceMuted,
              child: Text(email[0].toUpperCase(), style: TextStyle(color: active ? AppColors.teal500 : AppColors.textMuted, fontWeight: FontWeight.w700)),
            ),
            trailing: Switch(
              value: active,
              onChanged: (v) => _toggleActive(u['id'] as int, v),
            ),
          );
        }),
      ],
    );
  }
}
