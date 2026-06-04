import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/storage_service.dart';
import '../../shared/models/backtest_model.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/stat_card.dart';

final _resultProvider =
    FutureProvider.family.autoDispose<BacktestResult, int>((ref, runId) async {
  final response = await ApiClient.instance
      .get<Map<String, dynamic>>('/backtest/$runId/result');
  return BacktestResult.fromJson(response.data ?? {});
});

class ResultsScreen extends ConsumerWidget {
  final int? runId;
  const ResultsScreen({super.key, this.runId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (runId == null || runId == 0) {
      return AppScaffold(
        title: 'Results',
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_outlined, size: 64, color: cs.outlineVariant),
              const SizedBox(height: 16),
              Text('No run selected',
                  style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => context.go('/history'),
                child: const Text('Browse History'),
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
              Icon(Icons.hourglass_empty, size: 48, color: cs.outlineVariant),
              const SizedBox(height: 12),
              Text('Results not available yet',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(ApiClient.extractError(e),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(_resultProvider(runId!)),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (result) => _ResultsContent(result: result, runId: runId!),
      ),
    );
  }
}

class _ResultsContent extends StatelessWidget {
  final BacktestResult result;
  final int runId;
  const _ResultsContent({required this.result, required this.runId});

  String _fmt(dynamic v, {String prefix = '', String suffix = ''}) {
    if (v == null) return '-';
    if (v is double) return '$prefix${v.toStringAsFixed(2)}$suffix';
    if (v is int) return '$prefix$v$suffix';
    return '$prefix$v$suffix';
  }

  Color _profitColor(BuildContext context, dynamic v) {
    if (v == null) return Theme.of(context).colorScheme.onSurface;
    final d = v is double
        ? v
        : (v is int ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);
    return d >= 0 ? AppColors.success : Theme.of(context).colorScheme.error;
  }

  List<FlSpot> _buildEquitySpots() {
    double cumProfit = 0;
    final spots = <FlSpot>[];
    for (int i = 0; i < result.trades.length; i++) {
      final profit = result.trades[i]['profit'];
      final p = profit is double
          ? profit
          : (profit is int
              ? profit.toDouble()
              : double.tryParse(profit?.toString() ?? '0') ?? 0.0);
      cumProfit += p;
      spots.add(FlSpot(i.toDouble(), cumProfit));
    }
    return spots;
  }

  Future<void> _openReport(BuildContext context, String type) async {
    final serverUrl = await StorageService.instance.getServerUrl();
    final uri = Uri.parse('$serverUrl/backtest/$runId/report/$type');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open report')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final m = result.metrics;
    final equitySpots =
        result.trades.isNotEmpty ? _buildEquitySpots() : <FlSpot>[];
    final totalProfit = m['total_net_profit'] ?? m['net_profit'] ?? m['profit'];
    final drawdown = m['max_drawdown'] ?? m['drawdown'];
    final winRate = m['win_rate'] ?? m['percent_profitable'];
    final totalTrades = m['total_trades'] ?? result.trades.length;
    final sharpe = m['sharpe_ratio'];
    final profitFactor = m['profit_factor'];
    final recoveryFactor = m['recovery_factor'];
    final avgTrade = m['average_trade'] ?? m['expected_payoff'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Core metrics grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.8,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            StatCard(
              label: 'Net Profit',
              value: _fmt(totalProfit, prefix: '\$'),
              valueColor: _profitColor(context, totalProfit),
              icon: Icons.trending_up,
              iconColor: _profitColor(context, totalProfit),
            ),
            StatCard(
              label: 'Total Trades',
              value: _fmt(totalTrades),
              icon: Icons.swap_horiz,
            ),
            StatCard(
              label: 'Win Rate',
              value: _fmt(winRate, suffix: '%'),
              valueColor: AppColors.success,
              icon: Icons.percent,
              iconColor: AppColors.success,
            ),
            StatCard(
              label: 'Max Drawdown',
              value: _fmt(drawdown, suffix: '%'),
              valueColor: cs.error,
              icon: Icons.arrow_downward,
              iconColor: cs.error,
            ),
          ],
        ),
        // Extra metrics row
        if (sharpe != null || profitFactor != null || recoveryFactor != null || avgTrade != null) ...[
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.0,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              if (sharpe != null)
                StatCard(label: 'Sharpe Ratio', value: _fmt(sharpe)),
              if (profitFactor != null)
                StatCard(label: 'Profit Factor', value: _fmt(profitFactor)),
              if (recoveryFactor != null)
                StatCard(label: 'Recovery Factor', value: _fmt(recoveryFactor)),
              if (avgTrade != null)
                StatCard(
                    label: 'Avg Trade',
                    value: _fmt(avgTrade, prefix: '\$'),
                    valueColor: _profitColor(context, avgTrade)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // Equity curve
        if (equitySpots.length > 1) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EQUITY CURVE',
                      style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant, letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          getDrawingHorizontalLine: (_) => FlLine(
                              color: cs.outlineVariant, strokeWidth: 0.5),
                          getDrawingVerticalLine: (_) => FlLine(
                              color: cs.outlineVariant, strokeWidth: 0.5),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 56,
                              getTitlesWidget: (value, _) => Text(
                                '\$${value.toStringAsFixed(0)}',
                                style: tt.labelSmall
                                    ?.copyWith(color: cs.onSurfaceVariant, fontSize: 9),
                              ),
                            ),
                          ),
                          bottomTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: equitySpots,
                            isCurved: true,
                            color: cs.primary,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: cs.primary.withAlpha(30),
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
        // Trade Ledger link
        FilledButton.tonal(
          onPressed: () => context.push('/ledger?runId=$runId'),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.table_chart_outlined),
              SizedBox(width: 8),
              Text('View Trade Ledger'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Report downloads
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('REPORT DOWNLOADS',
                    style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openReport(context, 'html'),
                      icon: const Icon(Icons.html, size: 18),
                      label: const Text('HTML'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openReport(context, 'excel'),
                      icon: const Icon(Icons.table_chart, size: 18),
                      label: const Text('Excel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openReport(context, 'csv'),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('CSV'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Opens in your browser. Requires server connection.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
