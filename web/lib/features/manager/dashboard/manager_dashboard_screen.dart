import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/shell_scaffold.dart';
import '../../../services/repositories.dart';
import '../../../services/websocket_service.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  Map<String, dynamic>? _crisis;
  List<Map<String, dynamic>> _crowdReports = [];
  List<Map<String, dynamic>> _forecasts = [];
  String _forecastFuel = 'petrol_92';
  WebSocketChannel? _wsChannel;
  bool _liveConnected = false;

  late final _crisisRepo = CrisisRepository(widget.api);
  late final _stationRepo = StationRepository(widget.api);
  late final _forecastRepo = ForecastRepository(widget.api);
  late final _ws = StockWebSocketService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      if (_data == null) _data = null;
    });
    try {
      final dashRes = await widget.api.get('/manager/dashboard/');
      final crisis = await _crisisRepo.status();

      if (!mounted) return;
      if (dashRes.statusCode != 200) {
        setState(() {
          _data = {};
          _error = parseApiError(dashRes.body);
        });
        return;
      }

      final data = jsonDecode(dashRes.body) as Map<String, dynamic>;
      final station = data['station'] as Map<String, dynamic>?;
      final stationId = station?['id'] as int?;

      List<Map<String, dynamic>> crowd = [];
      List<Map<String, dynamic>> forecasts = [];
      if (stationId != null) {
        crowd = await _stationRepo.crowdReports(stationId);
        forecasts = await _forecastRepo.stationForecasts(stationId, fuelType: _forecastFuel);
        await _connectWebSocket(stationId);
      }

      if (!mounted) return;
      setState(() {
        _data = data;
        _crisis = crisis;
        _crowdReports = crowd;
        _forecasts = forecasts;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _connectWebSocket(int stationId) async {
    _wsChannel?.sink.close();
    final token = await widget.api.accessToken;
    if (token == null) return;
    try {
      final channel = _ws.connect(stationId: stationId, accessToken: token);
      _ws.listen(channel, (update) {
        if (!mounted || _data == null) return;
        final fuelType = update['fuel_type'] as String?;
        if (fuelType == null) return;
        final station = Map<String, dynamic>.from(_data!['station'] as Map<String, dynamic>);
        final stocks = List<Map<String, dynamic>>.from((station['stock_levels'] as List?) ?? []);
        final idx = stocks.indexWhere((s) => s['fuel_type'] == fuelType);
        if (idx >= 0) {
          stocks[idx] = {
            ...stocks[idx],
            'current_litres': update['current_litres'],
            'percentage': update['percentage'],
            'last_updated': update['last_updated'],
          };
        }
        station['stock_levels'] = stocks;
        setState(() {
          _data = {..._data!, 'station': station};
          _liveConnected = true;
        });
      });
      _wsChannel = channel;
      setState(() => _liveConnected = true);
    } catch (_) {
      setState(() => _liveConnected = false);
    }
  }

  Future<void> _reloadForecasts(int stationId) async {
    final forecasts = await _forecastRepo.stationForecasts(stationId, fuelType: _forecastFuel);
    if (mounted) setState(() => _forecasts = forecasts);
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null && _error == null) {
      return const ColoredBox(
        color: AppColors.surfaceLight,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_data == null || _data!.isEmpty) {
      return ColoredBox(
        color: AppColors.surfaceLight,
        child: Center(
          child: FsEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load dashboard',
            subtitle: _error ?? 'Check that the backend is running on port 8000',
            action: FilledButton(onPressed: _load, child: const Text('Retry')),
          ),
        ),
      );
    }

    final station = _data!['station'] as Map<String, dynamic>?;
    final stocks = List<Map<String, dynamic>>.from((station?['stock_levels'] as List?) ?? []);
    final deliveries = (_data!['recent_deliveries'] as List<dynamic>?) ?? [];
    final risks = (_data!['depletion_risks'] as List<dynamic>?) ?? [];
    final activity = (_data!['attendant_activity'] as List<dynamic>?) ?? [];
    final stationId = station?['id'] as int?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FsPageHeader(
          title: station?['name'] as String? ?? 'Station Dashboard',
          subtitle: '${formatDate(DateTime.now())}${station?['district'] != null ? ' · ${station!['district']}' : ''}${_liveConnected ? ' · Live' : ''}',
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
                  if (_crisis?['is_active'] == true) ...[
                    _CrisisBanner(crisis: _crisis!),
                    const SizedBox(height: AppSpacing.sectionGap),
                  ],
                  _buildKpiGrid(stocks.length, risks),
                  const SizedBox(height: AppSpacing.sectionGap),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth > 900;
                final stockSection = _buildStockSection(stocks, wide);
                final sideSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeliveries(deliveries),
                    const SizedBox(height: AppSpacing.sectionGap),
                    _buildRisks(risks),
                  ],
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: stockSection),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: sideSection),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [stockSection, const SizedBox(height: AppSpacing.sectionGap), sideSection],
                );
              },
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth > 900;
                final left = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAttendantActivity(activity),
                    const SizedBox(height: AppSpacing.sectionGap),
                    _buildCrowdReports(),
                  ],
                );
                final right = stationId == null
                    ? const SizedBox.shrink()
                    : _buildForecastSection(stationId);

                if (wide && stationId != null) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 16),
                      Expanded(child: right),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    left,
                    if (stationId != null) ...[const SizedBox(height: AppSpacing.sectionGap), right],
                  ],
                );
              },
            ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(int stockCount, List<dynamic> risks) {
    final redRisks = risks.where((r) => (r as Map)['risk_tier'] == 'red').length;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 2 : 1;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.kpiGap,
          crossAxisSpacing: AppSpacing.kpiGap,
          childAspectRatio: cols == 1 ? 2.2 : 1.85,
          children: [
            FsStatCard(
              label: 'Dispenses Today',
              value: '${_data!['dispense_today']}',
              icon: Icons.receipt_long_rounded,
              iconColor: AppColors.info,
            ),
            FsStatCard(
              label: 'Litres Dispensed',
              value: formatLitres(parseApiDouble(_data!['litres_today'])),
              icon: Icons.water_drop_rounded,
              iconColor: AppColors.teal500,
            ),
            FsStatCard(
              label: 'Fuel Types',
              value: '$stockCount',
              icon: Icons.local_gas_station_rounded,
              iconColor: AppColors.amber500,
            ),
            FsStatCard(
              label: 'Risk Alerts',
              value: '${risks.length}',
              icon: Icons.warning_amber_rounded,
              iconColor: redRisks > 0 ? AppColors.danger : risks.isNotEmpty ? AppColors.warning : AppColors.success,
              subtitle: redRisks > 0 ? '$redRisks critical' : risks.isNotEmpty ? 'Monitor closely' : 'All clear',
            ),
          ],
        );
      },
    );
  }

  Widget _buildStockSection(List<Map<String, dynamic>> stocks, bool wide) {
    return FsPanel(
      header: const FsPanelHeader(
        title: 'Tank Stock Levels',
        subtitle: 'Live capacity — updates via WebSocket',
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPad),
        child: stocks.isEmpty
            ? const FsEmptyState(icon: Icons.oil_barrel_outlined, title: 'No stock data', compact: true)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide && stocks.length > 1) ...[
                    SizedBox(height: 200, child: _StockBarChart(stocks: stocks)),
                    const SizedBox(height: 16),
                  ],
                  ...stocks.map((s) {
                    final ft = s['fuel_type'] as String;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FsStockGauge(
                        fuelType: ft,
                        percentage: double.parse(s['percentage'].toString()),
                        litres: s['current_litres']?.toString(),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }

  Widget _buildDeliveries(List<dynamic> deliveries) {
    return FsPanel(
      header: const FsPanelHeader(title: 'Recent Deliveries'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPad),
        child: deliveries.isEmpty
            ? const FsEmptyState(icon: Icons.local_shipping_outlined, title: 'No recent deliveries', compact: true)
            : Column(
                children: [
                  for (final d in deliveries.take(5))
                    Builder(builder: (context) {
                      final m = d as Map<String, dynamic>;
                      final ft = m['fuel_type'] as String;
                      return FsListTileCard(
                        title: '${formatLitres(parseApiDouble(m['litres']))} · ${fuelLabel(ft)}',
                        subtitle: formatDateTime(m['delivered_at']),
                        accentColor: AppColors.fuelColor(ft),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.teal500.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: AppColors.teal500, size: 18),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Widget _buildRisks(List<dynamic> risks) {
    return FsPanel(
      header: const FsPanelHeader(
        title: 'Depletion Risk Forecast',
        subtitle: 'LSTM model · 6h / 12h / 24h horizons',
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPad),
        child: risks.isEmpty
            ? const FsEmptyState(icon: Icons.check_circle_outline, title: 'No risk alerts', subtitle: 'All tanks are healthy', compact: true)
            : Column(
                children: [
                  for (final r in risks)
                    Builder(builder: (context) {
                      final m = r as Map<String, dynamic>;
                      final ft = m['fuel_type'] as String;
                      final tier = m['risk_tier'] as String;
                      final score = parseApiDouble(m['risk_score']);
                      final eta = m['estimated_hours_to_empty'];
                      final subtitle = StringBuffer('${m['horizon_hours']}h horizon');
                      if (score != null) subtitle.write(' · Score ${(score * 100).toStringAsFixed(0)}%');
                      if (eta != null) subtitle.write(' · ~${eta}h to empty');
                      return FsListTileCard(
                        title: fuelLabel(ft),
                        subtitle: subtitle.toString(),
                        accentColor: AppColors.riskColor(tier),
                        trailing: FsRiskBadge(tier: tier),
                        leading: Icon(fuelIcon(ft), color: AppColors.fuelColor(ft), size: 20),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Widget _buildAttendantActivity(List<dynamic> activity) {
    return FsPanel(
      header: const FsPanelHeader(
        title: "Today's Attendant Activity",
        subtitle: 'Dispense count by attendant',
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPad),
        child: activity.isEmpty
            ? const FsEmptyState(icon: Icons.person_outline, title: 'No dispenses today', subtitle: 'Activity will appear as attendants log fuel', compact: true)
            : Column(
                children: [
                  for (final a in activity)
                    Builder(builder: (context) {
                      final m = a as Map<String, dynamic>;
                      final email = m['attendant__email'] as String? ?? 'Unknown';
                      final count = m['count'] as int? ?? 0;
                      return FsListTileCard(
                        title: email,
                        subtitle: '$count dispense${count == 1 ? '' : 's'} today',
                        leading: CircleAvatar(
                          backgroundColor: AppColors.infoSoft,
                          child: Text(email[0].toUpperCase(), style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.w700)),
                        ),
                        trailing: Text('$count', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.teal500)),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Widget _buildCrowdReports() {
    return FsPanel(
      header: const FsPanelHeader(
        title: 'Crowd Reports',
        subtitle: 'Driver-submitted queue status (last 2h)',
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPad),
        child: _crowdReports.isEmpty
            ? const FsEmptyState(icon: Icons.groups_outlined, title: 'No crowd reports', subtitle: 'Drivers can report queue status from the mobile app', compact: true)
            : Column(
                children: [
                  for (final r in _crowdReports.take(6))
                    Builder(builder: (context) {
                      final ft = r['fuel_type'] as String;
                      final status = r['status'] as String? ?? 'unknown';
                      return FsListTileCard(
                        title: '${fuelLabel(ft)} · ${status.replaceAll('_', ' ')}',
                        subtitle: formatDateTime(r['reported_at']),
                        accentColor: AppColors.fuelColor(ft),
                        leading: const Icon(Icons.groups_rounded, color: AppColors.textSecondary, size: 20),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Widget _buildForecastSection(int stationId) {
    final chartData = _forecasts.take(24).toList();
    return FsPanel(
      header: FsPanelHeader(
        title: 'Demand Forecast',
        subtitle: 'Prophet model · 72h predicted demand',
        trailing: DropdownButton<String>(
          value: _forecastFuel,
          underline: const SizedBox.shrink(),
          isDense: true,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          items: const [
            DropdownMenuItem(value: 'petrol_92', child: Text('Petrol 92')),
            DropdownMenuItem(value: 'petrol_95', child: Text('Petrol 95')),
            DropdownMenuItem(value: 'auto_diesel', child: Text('Auto Diesel')),
            DropdownMenuItem(value: 'super_diesel', child: Text('Super Diesel')),
          ],
          onChanged: (v) async {
            if (v == null) return;
            setState(() => _forecastFuel = v);
            await _reloadForecasts(stationId);
          },
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPad),
        child: chartData.isEmpty
            ? const FsEmptyState(icon: Icons.show_chart, title: 'No forecast data', subtitle: 'Run ML forecasts on the backend to populate', compact: true)
            : SizedBox(
                height: 220,
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
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}L', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: chartData.length > 8 ? (chartData.length / 6).ceilToDouble() : 1,
                        getTitlesWidget: (i, _) {
                          if (i < 0 || i >= chartData.length) return const SizedBox();
                          final h = chartData[i.toInt()]['horizon_hours'];
                          return Text('${h}h', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < chartData.length; i++)
                          FlSpot(
                            i.toDouble(),
                            double.parse(chartData[i]['predicted_demand_litres'].toString()),
                          ),
                      ],
                      isCurved: true,
                      color: AppColors.fuelColor(_forecastFuel),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.fuelColor(_forecastFuel).withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}

class _CrisisBanner extends StatelessWidget {
  const _CrisisBanner({required this.crisis});

  final Map<String, dynamic> crisis;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emergency_rounded, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Crisis mode active', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.danger)),
                if ((crisis['message'] as String?)?.isNotEmpty == true)
                  Text(crisis['message'] as String, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockBarChart extends StatelessWidget {
  const _StockBarChart({required this.stocks});

  final List<Map<String, dynamic>> stocks;

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
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
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (i, _) {
                if (i >= stocks.length) return const SizedBox();
                final ft = stocks[i.toInt()]['fuel_type'] as String;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(fuelLabel(ft).split(' ').last, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: [
          for (var i = 0; i < stocks.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: double.parse(stocks[i]['percentage'].toString()),
                  color: AppColors.fuelColor(stocks[i]['fuel_type'] as String),
                  width: 28,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
