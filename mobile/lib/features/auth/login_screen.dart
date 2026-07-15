import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../services/auth_service.dart';
import '../attendant/attendant_shell.dart';
import '../driver/driver_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'driver@demo.fuelsense.lk');
  final _password = TextEditingController(text: 'DemoPass123');
  final _auth = AuthService();
  String? _error;
  bool _loading = false;
  bool _obscure = true;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _auth.login(_email.text.trim(), _password.text);
      if (!mounted) return;
      final role = me['role'] as String;
      final home = role == 'attendant' || role == 'station_manager'
          ? AttendantShell(api: _auth.api)
          : DriverShell(api: _auth.api);
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => home));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FsLoginLayout(
      title: 'Welcome back',
      subtitle: 'Sign in to find fuel, manage vehicles, or operate your station.',
      eyebrow: 'FuelSense LK · Mobile',
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Sign In'),
          ),
        ],
      ),
      footer: Text('Demo: driver@demo.fuelsense.lk', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
    );
  }
}
