import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/models.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/repositories.dart';

class FuelHistoryScreen extends StatefulWidget {
  const FuelHistoryScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<FuelHistoryScreen> createState() => _FuelHistoryScreenState();
}

class _FuelHistoryScreenState extends State<FuelHistoryScreen> {
  late final DispenseRepository _repo = DispenseRepository(widget.api);
  List<DispenseRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.history();
    setState(() => _records = list);
  }

  @override
  Widget build(BuildContext context) {
    final monthly = <String, double>{};
    for (final r in _records) {
      final key = DateFormat('yyyy-MM').format(r.dispensedAt);
      monthly[key] = (monthly[key] ?? 0) + r.litres;
    }
    final keys = monthly.keys.toList()..sort();
    final totalLitres = _records.fold<double>(0, (s, r) => s + r.litres);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FsPageHeader(
            title: 'Fuel History',
            subtitle: '${_records.length} transactions · ${totalLitres.toStringAsFixed(0)} L total',
          ),
          if (keys.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FsCard(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (i, _) {
                              if (i >= keys.length || i >= 6) return const SizedBox();
                              return Text(keys[i.toInt()].substring(5), style: const TextStyle(fontSize: 10, color: AppColors.textMuted));
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: [
                        for (var i = 0; i < keys.length && i < 6; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: monthly[keys[i]]!,
                                color: AppColors.amber500,
                                width: 20,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _records.isEmpty
                ? const FsEmptyState(icon: Icons.receipt_long_outlined, title: 'No transactions yet')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _records.length,
                    itemBuilder: (_, i) {
                      final r = _records[i];
                      final total = r.pricePerLitre != null ? r.litres * r.pricePerLitre! : null;
                      return FsListTileCard(
                        title: r.stationName,
                        subtitle: '${fuelLabel(r.fuelType)} · ${r.litres}L · ${DateFormat('d MMM').format(r.dispensedAt)}',
                        accentColor: AppColors.fuelColor(r.fuelType),
                        trailing: Text(
                          total != null ? 'Rs ${total.toStringAsFixed(0)}' : '',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.navy800),
                        ),
                        leading: Icon(fuelIcon(r.fuelType), color: AppColors.fuelColor(r.fuelType), size: 20),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
