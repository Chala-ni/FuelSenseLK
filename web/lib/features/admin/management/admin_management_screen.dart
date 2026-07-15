import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../core/api/api_client.dart';
import 'tabs/admin_deliveries_tab.dart';
import 'tabs/admin_prices_tab.dart';
import 'tabs/admin_users_tab.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FsPageHeader(title: 'Management', subtitle: 'Prices, users & delivery oversight'),
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Prices'),
            Tab(text: 'Users'),
            Tab(text: 'Deliveries'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              AdminPricesTab(api: widget.api),
              AdminUsersTab(api: widget.api),
              AdminDeliveriesTab(api: widget.api),
            ],
          ),
        ),
      ],
    );
  }
}
