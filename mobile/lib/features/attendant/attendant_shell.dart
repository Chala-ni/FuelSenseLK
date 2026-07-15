import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../core/api/api_client.dart';
import 'delivery/attendant_delivery_screen.dart';
import 'scanner/attendant_scanner_screen.dart';
import 'stock/attendant_stock_screen.dart';

class AttendantShell extends StatefulWidget {
  const AttendantShell({super.key, required this.api});

  final ApiClient api;

  @override
  State<AttendantShell> createState() => _AttendantShellState();
}

class _AttendantShellState extends State<AttendantShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      AttendantScannerScreen(api: widget.api),
      AttendantStockScreen(api: widget.api),
      AttendantDeliveryScreen(api: widget.api),
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
            NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded), selectedIcon: Icon(Icons.qr_code_scanner), label: 'Scan'),
            NavigationDestination(icon: Icon(Icons.local_gas_station_outlined), selectedIcon: Icon(Icons.local_gas_station_rounded), label: 'Stock'),
            NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping_rounded), label: 'Delivery'),
          ],
        ),
      ),
    );
  }
}
