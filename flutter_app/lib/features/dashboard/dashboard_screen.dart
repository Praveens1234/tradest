import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/shimmer_loading.dart';
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_outlined),
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(_healthProvider);
            ref.invalidate(_recentRunsProvider);
          },
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_healthProvider);
          ref.invalidate(_recentRunsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'SYSTEM HEALTH',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            healthAsync.when(
              loading: () => const Column(
                children: [
                  Row(children: [
                    Expanded(child: ShimmerStatCard()),
                    SizedBox(width: 12),
                    Expanded(child: ShimmerStatCard()),
                  ]),
                  SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: ShimmerStatCard()),
                    SizedBox(width: 12),
                    Expanded(child: ShimmerStatCard()),
                    SizedBox(width: 12),
                    Expanded(child: ShimmerStatCard()),
                  ]),
                ],
              ),
              error: (err, _) => _ErrorCard(
                message: ApiClient.extractError(err),
                onRetry: () => ref.invalidate(_healthProvider),
              ),
              data: (health) => _HealthSection(health: health),
            ),
            const SizedBox(height: 28),
            Text(
              'RECENT BACKTESTS',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            recentRunsAsync.when(
              loading: () => const ShimmerList(count: 4),
              error: (err, _) => _ErrorCard(
                message: ApiClient.extractError(err),
                onRetry: () => ref.invalidate(_recentRunsProvider),
              ),
              data: (runs) => _RecentRunsList(runs: runs),
            ),
          ],
        ),
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
    final cpu = health['cpu_percent'] as num? ?? 0;
    final mem = health['memory_mb'] as num? ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Terminal',
                value: terminalOk ? 'OK' : 'DOWN',
                valueColor: terminalOk ? AppColors.success : Theme.of(context).colorScheme.error,
                icon: terminalOk ? Icons.check_circle : Icons.error,
                iconColor: terminalOk ? AppColors.success : Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'MetaEditor',
                value: metaeditorOk ? 'OK' : 'DOWN',
                valueColor: metaeditorOk ? AppColors.success : Theme.of(context).colorScheme.error,
                icon: metaeditorOk ? Icons.check_circle : Icons.error,
                iconColor: metaeditorOk ? AppColors.success : Theme.of(context).colorScheme.error,
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
                valueColor: mql5Ok ? AppColors.success : Theme.of(context).colorScheme.error,
                icon: mql5Ok ? Icons.check_circle : Icons.error,
                iconColor: mql5Ok ? AppColors.success : Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CpuMemCard(cpu: cpu.toDouble(), mem: mem.toDouble()),
            ),
          ],
        ),
      ],
    );
  }
}

class _CpuMemCard extends StatelessWidget {
  final double cpu;
  final double mem;
  const _CpuMemCard({required this.cpu, required this.mem});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cpuColor = cpu > 80
        ? cs.error
        : cpu > 50
            ? AppColors.warning
            : AppColors.success;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resources',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.memory, size: 13, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('CPU ${cpu.toStringAsFixed(1)}%',
                style: tt.bodySmall?.copyWith(color: cs.onSurface)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: cpu / 100,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(cpuColor),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text('RAM ${mem.toStringAsFixed(0)} MB',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _RecentRunsList extends StatelessWidget {
  final List<BacktestRun> runs;
  const _RecentRunsList({required this.runs});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (runs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.history_outlined, size: 48, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text('No backtest runs yet',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/backtest/setup'),
              child: const Text('Run your first backtest →'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: runs.map((run) {
        final eaName = run.eaName ??
            run.parameters['ea_name']?.toString() ??
            'EA #${run.eaId ?? '?'}';
        final date = run.startedAt ?? '';
        final displayDate = date.length > 19 ? date.substring(0, 19) : date;
        final symbol = run.parameters['symbol']?.toString() ?? '';
        final period = run.parameters['period']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/results?runId=${run.runId}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          style: tt.titleSmall?.copyWith(color: cs.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [if (symbol.isNotEmpty) symbol, if (period.isNotEmpty) period, if (displayDate.isNotEmpty) displayDate]
                              .join(' • '),
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text('#${run.runId}',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 18),
                ],
              ),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer.withAlpha(60),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: tt.bodySmall?.copyWith(color: cs.onErrorContainer)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
