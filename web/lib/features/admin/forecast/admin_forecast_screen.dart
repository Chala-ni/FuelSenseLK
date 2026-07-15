import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/repositories.dart';

class AdminForecastScreen extends StatefulWidget {
  const AdminForecastScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminForecastScreen> createState() => _AdminForecastScreenState();
}

class _AdminForecastScreenState extends State<AdminForecastScreen> {
  late final _forecastRepo = ForecastRepository(widget.api);
  late final _stationRepo = StationRepository(widget.api);

  List<Map<String, dynamic>> _risks = [];
  List<Map<String, dynamic>> _stations = [];
  Map<String, dynamic>? _selectedStation;
  List<Map<String, dynamic>> _forecasts = [];
  String _fuelType = 'petrol_92';
  String _tierFilter = 'red';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _forecastRepo.depletionRisks(riskTier: _tierFilter.isEmpty ? null : _tierFilter),
        _stationRepo.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _risks = _sortRisks(results[0] as List<Map<String, dynamic>>);
        _stations = results[1] as List<Map<String, dynamic>>;
        if (_selectedStation == null && _stations.isNotEmpty) {
          _selectedStation = _stations.first;
        }
      });
      await _loadForecasts();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _sortRisks(List<Map<String, dynamic>> risks) {
    final sorted = List<Map<String, dynamic>>.from(risks);
    sorted.sort((a, b) {
      final tierOrder = {'red': 0, 'amber': 1, 'green': 2};
      final ta = tierOrder[a['risk_tier']] ?? 9;
      final tb = tierOrder[b['risk_tier']] ?? 9;
      if (ta != tb) return ta.compareTo(tb);
      final ha = (a['horizon_hours'] as int?) ?? 99;
      final hb = (b['horizon_hours'] as int?) ?? 99;
      if (ha != hb) return ha.compareTo(hb);
      return (parseApiDouble(b['risk_score']) ?? 0).compareTo(parseApiDouble(a['risk_score']) ?? 0);
    });
    return sorted;
  }

  Future<void> _loadForecasts() async {
    final station = _selectedStation;
    if (station == null) return;
    final forecasts = await _forecastRepo.stationForecasts(station['id'] as int, fuelType: _fuelType);
    if (mounted) setState(() => _forecasts = forecasts);
  }

  String _schedulingDecision(Map<String, dynamic> risk) {
    final tier = risk['risk_tier'] as String? ?? '';
    final horizon = risk['horizon_hours'] as int? ?? 24;
    final eta = parseApiDouble(risk['estimated_hours_to_empty']);
    if (tier == 'red' && horizon <= 12) return 'Schedule delivery urgently';
    if (tier == 'red') return 'Plan delivery within 24h';
    if (tier == 'amber' && eta != null && eta < 36) return 'Monitor · schedule if trend worsens';
    return 'No action required';
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.pageX, 12, 12, AppSpacing.pageY),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Depletion risk', style: Theme.of(context).textTheme.titleLarge),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final t in ['red', 'amber', ''])
                            FilterChip(
                              label: Text(t.isEmpty ? 'All tiers' : t.toUpperCase()),
                              selected: _tierFilter == t,
                              onSelected: (_) {
                                setState(() => _tierFilter = t);
                                _load();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_risks.isEmpty)
                        const FsEmptyState(icon: Icons.check_circle_outline, title: 'No matching risks')
                      else
                        FsCard(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AppColors.surfaceMuted),
                              columns: const [
                                DataColumn(label: Text('Station')),
                                DataColumn(label: Text('District')),
                                DataColumn(label: Text('Fuel')),
                                DataColumn(label: Text('Horizon')),
                                DataColumn(label: Text('Tier')),
                                DataColumn(label: Text('Score')),
                                DataColumn(label: Text('ETA empty')),
                                DataColumn(label: Text('Action')),
                              ],
                              rows: [
                                for (final r in _risks.take(50))
                                  DataRow(cells: [
                                    DataCell(Text(r['station_name'] as String? ?? '#${r['station']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text(r['district'] as String? ?? '—')),
                                    DataCell(Text(fuelLabel(r['fuel_type'] as String))),
                                    DataCell(Text('${r['horizon_hours']}h')),
                                    DataCell(FsRiskBadge(tier: r['risk_tier'] as String)),
                                    DataCell(Text('${((parseApiDouble(r['risk_score']) ?? 0) * 100).toStringAsFixed(0)}%')),
                                    DataCell(Text(r['estimated_hours_to_empty']?.toString() ?? '—')),
                                    DataCell(Text(_schedulingDecision(r), style: const TextStyle(fontSize: 12))),
                                  ]),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 12, AppSpacing.pageX, AppSpacing.pageY),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prophet Demand Forecast', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedStation,
                        decoration: const InputDecoration(labelText: 'Station'),
                        items: [
                          for (final s in _stations)
                            DropdownMenuItem(value: s, child: Text(s['name'] as String)),
                        ],
                        onChanged: (v) async {
                          setState(() => _selectedStation = v);
                          await _loadForecasts();
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final ft in ['petrol_92', 'petrol_95', 'auto_diesel', 'super_diesel'])
                            FilterChip(
                              label: Text(fuelLabel(ft)),
                              selected: _fuelType == ft,
                              onSelected: (_) async {
                                setState(() => _fuelType = ft);
                                await _loadForecasts();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_forecasts.isEmpty)
                        const FsEmptyState(icon: Icons.show_chart, title: 'No forecast data for station')
                      else
                        SizedBox(
                          height: 260,
                          child: FsCard(
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
                                ),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 42,
                                      getTitlesWidget: (v, _) => Text('${v.toInt()}L', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: _forecasts.length > 8 ? (_forecasts.length / 6).ceilToDouble() : 1,
                                      getTitlesWidget: (i, _) {
                                        if (i < 0 || i >= _forecasts.length) return const SizedBox();
                                        return Text('${_forecasts[i.toInt()]['horizon_hours']}h', style: const TextStyle(fontSize: 9));
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: [
                                      for (var i = 0; i < _forecasts.length; i++)
                                        FlSpot(i.toDouble(), double.parse(_forecasts[i]['predicted_demand_litres'].toString())),
                                    ],
                                    isCurved: true,
                                    color: AppColors.fuelColor(_fuelType),
                                    barWidth: 3,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: AppColors.fuelColor(_fuelType).withValues(alpha: 0.1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
  }
}
