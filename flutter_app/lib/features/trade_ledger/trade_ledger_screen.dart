import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../shared/models/backtest_model.dart';
import '../../shared/widgets/app_scaffold.dart';

final _ledgerProvider =
    FutureProvider.family.autoDispose<BacktestResult, int>((ref, runId) async {
  final response = await ApiClient.instance
      .get<Map<String, dynamic>>('/backtest/$runId/result');
  return BacktestResult.fromJson(response.data ?? {});
});

class TradeLedgerScreen extends ConsumerStatefulWidget {
  final int? runId;
  const TradeLedgerScreen({super.key, this.runId});

  @override
  ConsumerState<TradeLedgerScreen> createState() => _TradeLedgerScreenState();
}

class _TradeLedgerScreenState extends ConsumerState<TradeLedgerScreen> {
  int _sortCol = 0;
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (widget.runId == null || widget.runId == 0) {
      return AppScaffold(
        title: 'Trade Ledger',
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.table_chart_outlined,
                  size: 64, color: cs.outlineVariant),
              const SizedBox(height: 16),
              Text('No run selected',
                  style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => context.go('/history'),
                child: const Text('Browse History'),
              ),
            ],
          ),
        ),
      );
    }

    final resultAsync = ref.watch(_ledgerProvider(widget.runId!));

    return AppScaffold(
      title: 'Trade Ledger — Run #${widget.runId}',
      body: resultAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: cs.error, size: 48),
              const SizedBox(height: 12),
              Text(ApiClient.extractError(e),
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    ref.invalidate(_ledgerProvider(widget.runId!)),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (result) {
          final trades = result.trades;
          if (trades.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 48, color: cs.outlineVariant),
                  const SizedBox(height: 12),
                  Text('No trades in this run',
                      style: tt.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }

          final cols = trades.first.keys.toList();
          final sorted = _sortTrades(trades, cols);

          // Summary stats
          double totalProfit = 0;
          int profitable = 0;
          for (final t in trades) {
            final p = _toDouble(t['profit']);
            totalProfit += p;
            if (p > 0) profitable++;
          }

          return Column(
            children: [
              // Summary bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: cs.surfaceContainer,
                child: Row(
                  children: [
                    Text('${trades.length} trades',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(width: 16),
                    Text(
                      'Total: \$${totalProfit.toStringAsFixed(2)}',
                      style: tt.bodySmall?.copyWith(
                        color: totalProfit >= 0 ? AppColors.success : cs.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$profitable profitable',
                      style: tt.bodySmall?.copyWith(color: AppColors.success),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      sortColumnIndex: _sortCol,
                      sortAscending: _sortAscending,
                      columnSpacing: 16,
                      headingRowColor:
                          WidgetStateProperty.all(cs.surfaceContainer),
                      columns: cols
                          .asMap()
                          .entries
                          .map((entry) => DataColumn(
                                label: Text(
                                  entry.value,
                                  style: tt.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant),
                                ),
                                onSort: (colIdx, ascending) {
                                  setState(() {
                                    _sortCol = colIdx;
                                    _sortAscending = ascending;
                                  });
                                },
                              ))
                          .toList(),
                      rows: sorted.map((trade) {
                        final profit = trade['profit'];
                        final pVal = _toDouble(profit);
                        final profitColor =
                            pVal >= 0 ? AppColors.success : cs.error;
                        final rowBg = pVal > 0
                            ? AppColors.success.withAlpha(12)
                            : pVal < 0
                                ? cs.error.withAlpha(12)
                                : null;

                        return DataRow(
                          color: rowBg != null
                              ? WidgetStateProperty.all(rowBg)
                              : null,
                          cells: cols.map((c) {
                            final v = trade[c];
                            final str = v?.toString() ?? '-';
                            final isProfit = c == 'profit';
                            return DataCell(Text(
                              str,
                              style: TextStyle(
                                color: isProfit ? profitColor : cs.onSurface,
                                fontWeight: isProfit ? FontWeight.w600 : null,
                                fontSize: 12,
                              ),
                            ));
                          }).toList(),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _sortTrades(
      List<Map<String, dynamic>> trades, List<String> cols) {
    if (trades.isEmpty) return trades;
    final col = cols[_sortCol];
    final sorted = [...trades]..sort((a, b) {
        final av = a[col];
        final bv = b[col];
        final aDouble = _toDouble(av);
        final bDouble = _toDouble(bv);
        if (aDouble != 0 || bDouble != 0) {
          final result = aDouble.compareTo(bDouble);
          return _sortAscending ? result : -result;
        }
        final result = (av?.toString() ?? '').compareTo(bv?.toString() ?? '');
        return _sortAscending ? result : -result;
      });
    return sorted;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
