import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/repositories.dart';

class PriceHistoryScreen extends StatefulWidget {
  const PriceHistoryScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends State<PriceHistoryScreen> {
  late final PriceRepository _repo = PriceRepository(widget.api);
  List<Map<String, dynamic>> _prices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prices = await _repo.history();
    if (mounted) setState(() => _prices = prices);
  }

  @override
  Widget build(BuildContext context) {
    final byFuel = <String, List<double>>{};
    for (final p in _prices) {
      final ft = p['fuel_type'] as String;
      byFuel.putIfAbsent(ft, () => []).add(double.parse(p['price_per_litre'].toString()));
    }

    final chartColors = [AppColors.petrol92, AppColors.petrol95, AppColors.diesel, AppColors.superDiesel];

    return Scaffold(
      appBar: AppBar(title: const Text('Price History'), centerTitle: true),
      body: _prices.isEmpty
          ? const FsEmptyState(icon: Icons.trending_up_rounded, title: 'No price data available')
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                FsCard(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                  child: SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          for (var i = 0; i < byFuel.entries.length; i++)
                            LineChartBarData(
                              spots: [
                                for (var j = 0; j < byFuel.entries.elementAt(i).value.length; j++)
                                  FlSpot(j.toDouble(), byFuel.entries.elementAt(i).value[j]),
                              ],
                              isCurved: true,
                              color: chartColors[i % chartColors.length],
                              barWidth: 3,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: chartColors[i % chartColors.length].withValues(alpha: 0.08),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...byFuel.entries.map((e) {
                  final color = AppColors.fuelColor(e.key);
                  return FsListTileCard(
                    title: fuelLabel(e.key),
                    subtitle: 'Latest government price',
                    accentColor: color,
                    trailing: Text(
                      'Rs ${e.value.last.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    leading: Icon(fuelIcon(e.key), color: color, size: 20),
                  );
                }),
              ],
            ),
    );
  }
}
