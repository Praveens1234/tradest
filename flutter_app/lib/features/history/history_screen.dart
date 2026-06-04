import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../shared/models/backtest_model.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/shimmer_loading.dart';

final _historyProvider = FutureProvider.autoDispose<List<BacktestRun>>((ref) async {
  final response = await ApiClient.instance
      .get<List<dynamic>>('/backtest/history', params: {'limit': 100});
  return (response.data ?? [])
      .map((e) => BacktestRun.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _search = '';
  String? _statusFilter;

  static const _statusOptions = ['done', 'running', 'pending', 'failed', 'cancelled'];

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(_historyProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Backtest History',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SearchBar(
              hintText: 'Search by EA or symbol...',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _search = v),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _statusFilter == null,
                  onSelected: (_) => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 6),
                ..._statusOptions.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(_capitalize(s)),
                        selected: _statusFilter == s,
                        selectedColor: cs.primaryContainer,
                        onSelected: (sel) => setState(
                            () => _statusFilter = sel ? s : null),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: historyAsync.when(
              loading: () => const ShimmerList(count: 6),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: cs.error, size: 48),
                      const SizedBox(height: 12),
                      Text(ApiClient.extractError(e),
                          style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(_historyProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (runs) {
                final filtered = runs.where((run) {
                  final eaName = run.eaName ??
                      run.parameters['ea_name']?.toString() ??
                      '';
                  final symbol =
                      run.parameters['symbol']?.toString() ?? '';
                  final matchesSearch = _search.isEmpty ||
                      eaName.toLowerCase().contains(_search.toLowerCase()) ||
                      symbol.toLowerCase().contains(_search.toLowerCase());
                  final matchesStatus = _statusFilter == null ||
                      run.status == _statusFilter;
                  return matchesSearch && matchesStatus;
                }).toList();

                if (runs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_outlined,
                            size: 64, color: cs.outlineVariant),
                        const SizedBox(height: 16),
                        Text('No backtest runs yet',
                            style: tt.titleMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => context.go('/backtest/setup'),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Run a Backtest'),
                        ),
                      ],
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: cs.outlineVariant),
                        const SizedBox(height: 12),
                        Text('No runs match your filter',
                            style: tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_historyProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final run = filtered[i];
                      final eaName = run.eaName ??
                          run.parameters['ea_name']?.toString() ??
                          'EA #${run.eaId ?? '?'}';
                      final symbol =
                          run.parameters['symbol']?.toString() ?? '-';
                      final period =
                          run.parameters['period']?.toString() ?? '-';
                      final date = run.startedAt?.substring(0, 10) ?? '-';

                      return Card(
                        child: ListTile(
                          leading: StatusBadge(status: run.status),
                          title: Text(
                            '$eaName — $symbol $period',
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Run #${run.runId}  •  $date',
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          trailing: run.status == 'done'
                              ? Icon(Icons.chevron_right,
                                  color: cs.primary)
                              : null,
                          onTap: run.status == 'done'
                              ? () => context
                                  .push('/results?runId=${run.runId}')
                              : (run.status == 'running' ||
                                      run.status == 'pending')
                                  ? () => context.push(
                                      '/backtest/monitor/${run.runId}')
                                  : null,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
