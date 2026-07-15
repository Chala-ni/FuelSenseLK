import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import 'features/attendant/attendant_shell.dart';
import 'features/auth/login_screen.dart';
import 'features/driver/driver_shell.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const FuelSenseApp());
}

class FuelSenseApp extends StatelessWidget {
  const FuelSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FuelSense LK',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const BootstrapScreen(),
    );
  }
}

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final role = await _auth.storedRole();
    if (!mounted) return;
    if (role == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final home = role == 'attendant' || role == 'station_manager'
        ? AttendantShell(api: _auth.api)
        : DriverShell(api: _auth.api);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => home));
  }

  @override
  Widget build(BuildContext context) {
    return const FsLoadingScreen(message: 'Starting FuelSense…');
  }
}
