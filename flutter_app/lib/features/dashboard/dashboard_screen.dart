import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/models/backtest_model.dart';

final _healthProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response = await ApiClient.instance.get<Map<String, dynamic>>('/health');
  return response.data ?? {};
});

final _recentRunsProvider = FutureProvider.autoDispose<List<BacktestRun>>((ref) async {
  final response = await ApiClient.instance.get<List<dynamic>>(
    '/backtest/history',
    params: {'limit': 5},
  );
  final list = response.data ?? [];
  return list
      .map((e) => BacktestRun.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(_healthProvider);
    final recentRunsAsync = ref.watch(_recentRunsProvider);

    return AppScaffold(
      title: 'Dashboard',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_healthProvider);
          ref.invalidate(_recentRunsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('System Health'),
            const SizedBox(height: 12),
            healthAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => _ErrorCard(
                message: err.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(_healthProvider),
              ),
              data: (health) => _HealthSection(health: health),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Recent Backtests'),
            const SizedBox(height: 12),
            recentRunsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => _ErrorCard(
                message: err.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(_recentRunsProvider),
              ),
              data: (runs) => _RecentRunsList(runs: runs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF9CA3AF),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _HealthSection extends StatelessWidget {
  final Map<String, dynamic> health;

  const _HealthSection({required this.health});

  @override
  Widget build(BuildContext context) {
    final terminalOk = health['terminal_ok'] as bool? ?? false;
    final metaeditorOk = health['metaeditor_ok'] as bool? ?? false;
    final mql5Ok = health['mql5_ok'] as bool? ?? false;
    final cpu = health['cpu_percent'];
    final mem = health['memory_mb'];

    final cpuStr = cpu != null ? '${cpu.toStringAsFixed(1)}%' : 'N/A';
    final memStr = mem != null ? '${(mem as num).toStringAsFixed(0)} MB' : 'N/A';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Terminal',
                value: terminalOk ? 'OK' : 'DOWN',
                valueColor: terminalOk
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
                icon: terminalOk ? Icons.check_circle : Icons.error,
                iconColor: terminalOk
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'MetaEditor',
                value: metaeditorOk ? 'OK' : 'DOWN',
                valueColor: metaeditorOk
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
                icon: metaeditorOk ? Icons.check_circle : Icons.error,
                iconColor: metaeditorOk
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'MQL5',
                value: mql5Ok ? 'OK' : 'DOWN',
                valueColor: mql5Ok
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
                icon: mql5Ok ? Icons.check_circle : Icons.error,
                iconColor: mql5Ok
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'CPU Usage',
                value: cpuStr,
                icon: Icons.memory,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Memory',
                value: memStr,
                icon: Icons.storage,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecentRunsList extends StatelessWidget {
  final List<BacktestRun> runs;

  const _RecentRunsList({required this.runs});

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No backtest runs yet',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return Column(
      children: runs.map((run) {
        final eaName = run.eaName ??
            run.parameters['ea_name']?.toString() ??
            'EA #${run.eaId ?? '?'}';
        final date = run.startedAt ?? 'Unknown date';
        final displayDate = date.length > 19 ? date.substring(0, 19) : date;

        return GestureDetector(
          onTap: () => context.go('/results?runId=${run.runId}'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                StatusBadge(status: run.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eaName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayDate,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '#${run.runId}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF6B7280),
                  size: 18,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withAlpha(77)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
