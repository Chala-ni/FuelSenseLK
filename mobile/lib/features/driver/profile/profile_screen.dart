import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../services/auth_service.dart';
import '../../auth/login_screen.dart';
import '../prices/price_history_screen.dart';
import '../vehicles/vehicle_management_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.amber500.withValues(alpha: 0.2),
                    child: const Icon(Icons.person_rounded, color: AppColors.amber400, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Account', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textOnDark)),
                        Text('Driver profile', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textOnDark.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _MenuSection(
            title: 'Vehicles & Fuel',
            items: [
              _MenuItem(icon: Icons.directions_car_rounded, label: 'My Vehicles', color: AppColors.info, onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleManagementScreen(api: api)));
              }),
              _MenuItem(icon: Icons.show_chart_rounded, label: 'Price Charts', color: AppColors.teal500, onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PriceHistoryScreen(api: api)));
              }),
            ],
          ),
          _MenuSection(
            title: 'Settings',
            items: [
              _MenuItem(icon: Icons.notifications_outlined, label: 'Notifications', subtitle: 'Coming in Sprint 6', color: AppColors.textMuted, onTap: () {}),
              _MenuItem(icon: Icons.logout_rounded, label: 'Sign Out', color: AppColors.danger, onTap: () async {
                await AuthService(api: api).logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.items});

  final String title;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
          FsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1) const Divider(height: 1, indent: 56),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.color, this.subtitle, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
    );
  }
}
