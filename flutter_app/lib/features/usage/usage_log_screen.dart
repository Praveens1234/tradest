import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/shimmer_loading.dart';

final _usageProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient.instance
      .get<List<dynamic>>('/usage/events', params: {'limit': 100});
  return (response.data ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

class UsageLogScreen extends ConsumerStatefulWidget {
  const UsageLogScreen({super.key});

  @override
  ConsumerState<UsageLogScreen> createState() => _UsageLogScreenState();
}

class _UsageLogScreenState extends ConsumerState<UsageLogScreen> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final usageAsync = ref.watch(_usageProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Usage Log',
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _statusFilter == null,
                  onSelected: (_) => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Success'),
                  selected: _statusFilter == 'success',
                  selectedColor: AppColors.success.withAlpha(50),
                  onSelected: (sel) =>
                      setState(() => _statusFilter = sel ? 'success' : null),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Error'),
                  selected: _statusFilter == 'error',
                  selectedColor: cs.errorContainer,
                  onSelected: (sel) =>
                      setState(() => _statusFilter = sel ? 'error' : null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: usageAsync.when(
              loading: () => const ShimmerList(count: 8),
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
                      onPressed: () => ref.invalidate(_usageProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (events) {
                final filtered = _statusFilter == null
                    ? events
                    : events
                        .where((e) => e['status']?.toString() == _statusFilter)
                        .toList();

                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.list_alt_outlined,
                            size: 48, color: cs.outlineVariant),
                        const SizedBox(height: 12),
                        Text('No events yet',
                            style: tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_usageProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      final ts = e['timestamp']?.toString() ?? '';
                      final date = ts.length > 19 ? ts.substring(0, 19) : ts;
                      final status = e['status']?.toString() ?? 'unknown';
                      final statusColor = status == 'success'
                          ? AppColors.success
                          : status == 'error'
                              ? cs.error
                              : cs.onSurfaceVariant;
                      final duration = e['duration_ms'];
                      final durationStr = duration != null
                          ? '${duration}ms'
                          : '';

                      return Card(
                        child: ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              e['interface']?.toString() ?? 'API',
                              style: tt.labelSmall?.copyWith(
                                  color: cs.onPrimaryContainer),
                            ),
                          ),
                          title: Text(
                            e['action']?.toString() ?? '-',
                            style:
                                tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            [date, if (durationStr.isNotEmpty) durationStr]
                                .join(' • '),
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: tt.labelSmall?.copyWith(color: statusColor),
                            ),
                          ),
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
}
