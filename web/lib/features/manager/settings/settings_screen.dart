import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/shell_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final me = await widget.api.me();
    if (!mounted) return;
    if (me != null) {
      _firstName.text = me['first_name'] as String? ?? '';
      _lastName.text = me['last_name'] as String? ?? '';
    }
    setState(() {
      _profile = me;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final res = await widget.api.patch('/auth/me/', {
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
      });
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
        setState(() => _profile = jsonDecode(res.body) as Map<String, dynamic>);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final email = _profile?['email'] as String? ?? '';
    final role = _profile?['role'] as String? ?? '';

    return DashboardPage(
      title: 'Settings',
      subtitle: 'Account & session',
      child: Column(
        children: [
          FsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primarySoft,
                      child: Text(email.isNotEmpty ? email[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: Theme.of(context).textTheme.titleMedium),
                          Text(formatRole(role), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _firstName, decoration: const InputDecoration(labelText: 'First name'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _lastName, decoration: const InputDecoration(labelText: 'Last name'))),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          FsCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link, size: 18, color: AppColors.textMuted),
              title: const Text('API endpoint', style: TextStyle(fontSize: 13)),
              subtitle: Text(widget.api.baseUrl, style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}
