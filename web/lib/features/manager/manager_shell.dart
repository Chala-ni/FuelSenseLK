import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/shell_scaffold.dart';
import 'dashboard/manager_dashboard_screen.dart';
import 'operations/operations_screen.dart';
import 'settings/settings_screen.dart';
import 'staff/staff_screen.dart';

class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key, required this.api});

  final ApiClient api;

  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<ManagerShell> {
  int _index = 0;

  static const _destinations = [
    ShellDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Dashboard'),
    ShellDestination(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: 'Operations'),
    ShellDestination(icon: Icons.people_outline_rounded, selectedIcon: Icons.people_rounded, label: 'Staff'),
    ShellDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      api: widget.api,
      appName: 'FuelSense LK',
      roleLabel: 'MANAGER',
      destinations: _destinations,
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      pages: [
        ManagerDashboardScreen(api: widget.api),
        OperationsScreen(api: widget.api),
        ManagerStaffScreen(api: widget.api),
        SettingsScreen(api: widget.api),
      ],
    );
  }
}
