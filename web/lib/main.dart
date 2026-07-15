import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import 'core/api/api_client.dart';
import 'core/routing/home_router.dart';
import 'features/auth/login_screen.dart';

void main() => runApp(const FuelSenseWebApp());

class FuelSenseWebApp extends StatelessWidget {
  const FuelSenseWebApp({super.key});

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
    final ok = await _auth.api.ensureAuthenticated();
    if (!mounted) return;
    if (!ok) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    final role = await _auth.api.role;
    if (!isManagerWebRole(role)) {
      await _auth.api.clear();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => homeForRole(_auth.api, role)),
    );
  }

  @override
  Widget build(BuildContext context) => const FsLoadingScreen(message: 'Loading dashboard…');
}
