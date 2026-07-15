import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../core/api/api_client.dart';
import 'finder/smart_finder_screen.dart';
import 'history/fuel_history_screen.dart';
import 'map/driver_map_screen.dart';
import 'profile/profile_screen.dart';
import 'qr/vehicle_qr_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key, required this.api});

  final ApiClient api;

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DriverMapScreen(api: widget.api),
      SmartFinderScreen(api: widget.api),
      VehicleQrScreen(api: widget.api),
      FuelHistoryScreen(api: widget.api),
      ProfileScreen(api: widget.api),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Map'),
            NavigationDestination(icon: Icon(Icons.search_rounded), selectedIcon: Icon(Icons.manage_search_rounded), label: 'Find'),
            NavigationDestination(icon: Icon(Icons.qr_code_rounded), selectedIcon: Icon(Icons.qr_code_2_rounded), label: 'QR'),
            NavigationDestination(icon: Icon(Icons.history_rounded), selectedIcon: Icon(Icons.history_rounded), label: 'History'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
