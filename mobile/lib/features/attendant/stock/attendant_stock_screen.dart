import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../services/attendant_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/websocket_service.dart';

class AttendantStockScreen extends StatefulWidget {
  const AttendantStockScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AttendantStockScreen> createState() => _AttendantStockScreenState();
}

class _AttendantStockScreenState extends State<AttendantStockScreen> {
  Map<String, dynamic>? _station;
  final Map<String, double> _livePct = {};
  String _lastUpdate = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await AuthService(api: widget.api).meProfile();
    final stationId = me['station'] as int?;
    if (stationId == null) return;
    final data = await StationRepository(widget.api).getStation(stationId);
    setState(() => _station = data);
    final token = await widget.api.accessToken;
    if (token != null) {
      final channel = StockWebSocketService().connect(stationId: stationId, accessToken: token);
      channel.stream.listen((event) {
        final map = jsonDecode(event as String) as Map<String, dynamic>;
        if (map['fuel_type'] != null) {
          setState(() {
            _livePct[map['fuel_type'] as String] = (map['percentage'] as num).toDouble();
            _lastUpdate = map['timestamp'] as String? ?? '';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stocks = (_station?['stock_levels'] as List<dynamic>? ?? []);

    return Scaffold(
      body: stocks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FsPageHeader(
                  title: 'Live Stock',
                  subtitle: _station?['name'] as String? ?? 'Your station',
                  trailing: _lastUpdate.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.successSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text('LIVE', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      for (final s in stocks)
                        Builder(
                          builder: (context) {
                            final ft = s['fuel_type'] as String;
                            final pct = _livePct[ft] ?? double.parse(s['percentage'].toString());
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: FsStockGauge(
                                fuelType: ft,
                                percentage: pct,
                                litres: s['current_litres']?.toString(),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
