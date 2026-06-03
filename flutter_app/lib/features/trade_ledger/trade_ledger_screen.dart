import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../shared/models/backtest_model.dart';
import '../../shared/widgets/app_scaffold.dart';

final _ledgerProvider = FutureProvider.family.autoDispose<BacktestResult, int>((ref, runId) async {
  final response = await ApiClient.instance.get<Map<String, dynamic>>('/backtest/$runId/result');
  return BacktestResult.fromJson(response.data ?? {});
});

class TradeLedgerScreen extends ConsumerWidget {
  final int? runId;
  const TradeLedgerScreen({super.key, this.runId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (runId == null || runId == 0) {
      return AppScaffold(
        title: 'Trade Ledger',
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.table_chart_outlined, size: 64, color: Color(0xFF374151)),
              const SizedBox(height: 16),
              const Text('No run selected', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 18)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => context.go('/history'),
                child: const Text('Browse History'),
              ),
            ],
          ),
        ),
      );
    }

    final resultAsync = ref.watch(_ledgerProvider(runId!));

    return AppScaffold(
      title: 'Trade Ledger — Run #$runId',
      body: resultAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Color(0xFFEF4444)))),
        data: (result) {
          final trades = result.trades;
          if (trades.isEmpty) {
            return const Center(
              child: Text('No trades in this run', style: TextStyle(color: Color(0xFF9CA3AF))));
          }
          final cols = trades.first.keys.toList();
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16,
                headingRowColor: WidgetStateProperty.all(const Color(0xFF111827)),
                columns: cols.map((c) => DataColumn(
                  label: Text(c, style: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold, fontSize: 12)),
                )).toList(),
                rows: trades.map((trade) {
                  final profit = trade['profit'];
                  final pVal = profit is double ? profit : (profit is int ? profit.toDouble() : double.tryParse(profit?.toString() ?? '') ?? 0.0);
                  final profitColor = pVal >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

                  return DataRow(
                    cells: cols.map((c) {
                      final v = trade[c];
                      final str = v?.toString() ?? '-';
                      final isProfit = c == 'profit';
                      return DataCell(Text(
                        str,
                        style: TextStyle(
                          color: isProfit ? profitColor : const Color(0xFFE5E7EB),
                          fontWeight: isProfit ? FontWeight.w600 : null,
                          fontSize: 12,
                        ),
                      ));
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}
