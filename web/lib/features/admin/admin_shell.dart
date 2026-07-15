import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/shell_scaffold.dart';
import 'analytics/admin_analytics_screen.dart';
import 'crisis/admin_crisis_screen.dart';
import 'forecast/admin_forecast_screen.dart';
import 'management/admin_management_screen.dart';
import 'network/admin_network_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _destinations = [
    ShellDestination(icon: Icons.map_outlined, selectedIcon: Icons.map_rounded, label: 'Network'),
    ShellDestination(icon: Icons.insights_outlined, selectedIcon: Icons.insights_rounded, label: 'Forecasting'),
    ShellDestination(icon: Icons.analytics_outlined, selectedIcon: Icons.analytics_rounded, label: 'Analytics'),
    ShellDestination(icon: Icons.emergency_outlined, selectedIcon: Icons.emergency_rounded, label: 'Crisis'),
    ShellDestination(icon: Icons.tune_outlined, selectedIcon: Icons.tune_rounded, label: 'Management'),
  ];

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      api: widget.api,
      appName: 'FuelSense LK',
      roleLabel: 'ADMIN',
      destinations: _destinations,
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      pages: [
        AdminNetworkScreen(api: widget.api),
        AdminForecastScreen(api: widget.api),
        AdminAnalyticsScreen(api: widget.api),
        AdminCrisisScreen(api: widget.api),
        AdminManagementScreen(api: widget.api),
      ],
    );
  }
}
