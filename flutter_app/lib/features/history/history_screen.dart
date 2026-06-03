import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../shared/models/backtest_model.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/status_badge.dart';

final _historyProvider = FutureProvider.autoDispose<List<BacktestRun>>((ref) async {
  final response = await ApiClient.instance.get<List<dynamic>>('/backtest/history', params: {'limit': 50});
  return (response.data ?? [])
      .map((e) => BacktestRun.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_historyProvider);

    return AppScaffold(
      title: 'Backtest History',
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Color(0xFFEF4444)))),
        data: (runs) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(_historyProvider),
          child: runs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, size: 64, color: Color(0xFF374151)),
                      const SizedBox(height: 16),
                      const Text('No backtest runs yet', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 18)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/backtest/setup'),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Run a Backtest'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: runs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final run = runs[i];
                    final symbol = run.parameters['symbol']?.toString() ?? '-';
                    final period = run.parameters['period']?.toString() ?? '-';
                    final date = run.startedAt?.substring(0, 10) ?? '-';

                    return Card(
                      child: ListTile(
                        leading: StatusBadge(status: run.status),
                        title: Text('Run #${run.runId} — $symbol $period',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'EA: ${run.eaId != null ? '#${run.eaId}' : 'Unknown'}  •  $date',
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                        ),
                        trailing: run.status == 'done'
                            ? const Icon(Icons.chevron_right, color: Color(0xFF3B82F6))
                            : null,
                        onTap: run.status == 'done'
                            ? () => context.push('/results?runId=${run.runId}')
                            : run.status == 'running' || run.status == 'pending'
                                ? () => context.push('/backtest/monitor/${run.runId}')
                                : null,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
