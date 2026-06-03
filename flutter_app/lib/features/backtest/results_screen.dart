import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/api_client.dart';
import '../../shared/models/backtest_model.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/stat_card.dart';

final _resultProvider = FutureProvider.family.autoDispose<BacktestResult, int>((ref, runId) async {
  final response = await ApiClient.instance.get<Map<String, dynamic>>('/backtest/$runId/result');
  return BacktestResult.fromJson(response.data ?? {});
});

class ResultsScreen extends ConsumerWidget {
  final int? runId;
  const ResultsScreen({super.key, this.runId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (runId == null || runId == 0) {
      return AppScaffold(
        title: 'Results',
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bar_chart_outlined, size: 64, color: Color(0xFF374151)),
              const SizedBox(height: 16),
              const Text('No run selected', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 18)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/history'),
                child: const Text('Go to History →'),
              ),
            ],
          ),
        ),
      );
    }

    final resultAsync = ref.watch(_resultProvider(runId!));

    return AppScaffold(
      title: 'Results — Run #$runId',
      body: resultAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_empty, size: 48, color: Color(0xFF374151)),
              const SizedBox(height: 12),
              const Text('Results not available yet', style: TextStyle(color: Color(0xFF9CA3AF))),
              const SizedBox(height: 4),
              Text(e.toString(), style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
            ],
          ),
        ),
        data: (result) => _ResultsContent(result: result),
      ),
    );
  }
}

class _ResultsContent extends StatelessWidget {
  final BacktestResult result;
  const _ResultsContent({required this.result});

  String _fmt(dynamic v, {String prefix = '', String suffix = ''}) {
    if (v == null) return '-';
    if (v is double) return '$prefix${v.toStringAsFixed(2)}$suffix';
    if (v is int) return '$prefix$v$suffix';
    return '$prefix$v$suffix';
  }

  Color _profitColor(dynamic v) {
    if (v == null) return Colors.white;
    final d = v is double ? v : (v is int ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    return d >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
  }

  List<FlSpot> _buildEquitySpots() {
    double cumProfit = 0;
    final spots = <FlSpot>[];
    for (int i = 0; i < result.trades.length; i++) {
      final profit = result.trades[i]['profit'];
      final p = profit is double ? profit : (profit is int ? profit.toDouble() : double.tryParse(profit?.toString() ?? '0') ?? 0.0);
      cumProfit += p;
      spots.add(FlSpot(i.toDouble(), cumProfit));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final m = result.metrics;
    final equitySpots = result.trades.isNotEmpty ? _buildEquitySpots() : <FlSpot>[];
    final totalProfit = m['total_net_profit'] ?? m['net_profit'] ?? m['profit'];
    final drawdown = m['max_drawdown'] ?? m['drawdown'];
    final winRate = m['win_rate'] ?? m['percent_profitable'];
    final totalTrades = m['total_trades'] ?? result.trades.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.8,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            StatCard(
              label: 'Net Profit',
              value: _fmt(totalProfit, prefix: '\$'),
              valueColor: _profitColor(totalProfit),
            ),
            StatCard(
              label: 'Total Trades',
              value: _fmt(totalTrades),
            ),
            StatCard(
              label: 'Win Rate',
              value: _fmt(winRate, suffix: '%'),
              valueColor: const Color(0xFF22C55E),
            ),
            StatCard(
              label: 'Max Drawdown',
              value: _fmt(drawdown, suffix: '%'),
              valueColor: const Color(0xFFEF4444),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (equitySpots.length > 1) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Equity Curve', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFF374151), strokeWidth: 0.5),
                          getDrawingVerticalLine: (_) => const FlLine(color: Color(0xFF374151), strokeWidth: 0.5),
                        ),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: equitySpots,
                            isCurved: true,
                            color: const Color(0xFF3B82F6),
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF3B82F6).withAlpha(26),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('REPORT DOWNLOADS', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(
                  'Reports available at:\n'
                  '• /backtest/${result.runId}/report/html\n'
                  '• /backtest/${result.runId}/report/excel\n'
                  '• /backtest/${result.runId}/report/csv',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
