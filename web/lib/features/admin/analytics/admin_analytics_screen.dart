import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/repositories.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  late final _analytics = AnalyticsRepository(widget.api);
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _analytics.network();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FsEmptyState(
          icon: Icons.error_outline,
          title: 'Analytics unavailable',
          subtitle: _error,
          action: FilledButton(onPressed: _load, child: const Text('Retry')),
        ),
      );
    }

    final summary = _data!['summary'] as Map<String, dynamic>;
    final trend = List<Map<String, dynamic>>.from((_data!['dispense_trend'] as List?) ?? []);
    final districts = List<Map<String, dynamic>>.from((_data!['district_breakdown'] as List?) ?? []);
    final stockHealth = List<Map<String, dynamic>>.from((_data!['stock_health'] as List?) ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FsPageHeader(
          title: 'Network Analytics',
          subtitle: 'Aggregated metrics across all stations',
          trailing: IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _load),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.pageX, 0, AppSpacing.pageX, AppSpacing.pageY),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 1000 ? 4 : c.maxWidth > 600 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.kpiGap,
                  crossAxisSpacing: AppSpacing.kpiGap,
                  childAspectRatio: 2.0,
                  children: [
                    FsStatCard(label: 'Stations', value: '${summary['total_stations']}', icon: Icons.hub_rounded, iconColor: AppColors.teal500),
                    FsStatCard(label: 'Dispenses Today', value: '${summary['dispense_today']}', icon: Icons.receipt_long, iconColor: AppColors.info),
                    FsStatCard(label: 'Litres Today', value: formatLitres(parseApiDouble(summary['litres_today'])), icon: Icons.water_drop, iconColor: AppColors.amber500),
                    FsStatCard(
                      label: 'Avg Stock',
                      value: formatPercent(parseApiDouble(summary['avg_stock_pct'])),
                      icon: Icons.speed_rounded,
                      iconColor: AppColors.success,
                      subtitle: '${summary['red_risk_count']} red · ${summary['amber_risk_count']} amber',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth > 900;
                final trendChart = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FsSectionHeader(title: '7-Day Dispense Trend'),
                    SizedBox(
                      height: 240,
                      child: FsCard(
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            gridData: FlGridData(show: true, drawVerticalLine: false),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (i, _) {
                                    if (i < 0 || i >= trend.length) return const SizedBox();
                                    return Text(formatShortDate(trend[i.toInt()]['date']), style: const TextStyle(fontSize: 9));
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 36,
                                  getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9)),
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            barGroups: [
                              for (var i = 0; i < trend.length; i++)
                                BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: parseApiDouble(trend[i]['count']) ?? 0,
                                      color: AppColors.teal500,
                                      width: 18,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );

                final districtSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FsSectionHeader(title: 'District Breakdown'),
                    ...districts.take(8).map((d) {
                      return FsListTileCard(
                        title: d['district'] as String,
                        subtitle: '${d['stations']} stations · avg ${formatPercent(parseApiDouble(d['avg_stock_pct']))}',
                        trailing: (d['red_risks'] as int? ?? 0) > 0
                            ? FsRiskBadge(tier: 'red')
                            : Text('${d['stations']}', style: Theme.of(context).textTheme.titleMedium),
                      );
                    }),
                  ],
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: trendChart),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: districtSection),
                    ],
                  );
                }
                return Column(children: [trendChart, const SizedBox(height: 24), districtSection]);
              },
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            const FsSectionHeader(title: 'Stock Health by Fuel Type'),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final sh in stockHealth)
                  SizedBox(
                    width: 220,
                    child: FsStatCard(
                      label: fuelLabel(sh['fuel_type'] as String),
                      value: formatPercent(parseApiDouble(sh['avg_pct'])),
                      icon: fuelIcon(sh['fuel_type'] as String),
                      iconColor: AppColors.fuelColor(sh['fuel_type'] as String),
                      subtitle: '${sh['below_25']} below 25%',
                    ),
                  ),
              ],
            ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
