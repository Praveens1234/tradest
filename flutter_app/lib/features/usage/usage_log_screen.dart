import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/shimmer_loading.dart';

typedef _UsageFilter = ({String? action, String? date});

final _usageProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, _UsageFilter>((ref, filter) async {
  final params = <String, dynamic>{'limit': 100};
  if (filter.action != null) params['action'] = filter.action;
  if (filter.date != null) params['date'] = filter.date;
  final response =
      await ApiClient.instance.get<List<dynamic>>('/usage/events', params: params);
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
  String? _actionFilter;
  DateTime? _dateFilter;

  static const _actionOptions = ['compile', 'backtest', 'upload', 'login'];

  _UsageFilter get _filter => (
        action: _actionFilter,
        date: _dateFilter != null
            ? DateFormat('yyyy-MM-dd').format(_dateFilter!)
            : null,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateFilter = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usageAsync = ref.watch(_usageProvider(_filter));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Usage Log',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_outlined),
          onPressed: () => ref.invalidate(_usageProvider(_filter)),
        ),
      ],
      body: Column(
        children: [
          // Status chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Status'),
                  selected: _statusFilter == null,
                  onSelected: (_) => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Ok'),
                  selected: _statusFilter == 'ok',
                  selectedColor: AppColors.success.withAlpha(50),
                  onSelected: (sel) =>
                      setState(() => _statusFilter = sel ? 'ok' : null),
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
          // Action + date chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Actions'),
                  selected: _actionFilter == null,
                  onSelected: (_) => setState(() => _actionFilter = null),
                ),
                const SizedBox(width: 6),
                ..._actionOptions.map((a) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(a),
                        selected: _actionFilter == a,
                        selectedColor: cs.primaryContainer,
                        onSelected: (sel) =>
                            setState(() => _actionFilter = sel ? a : null),
                      ),
                    )),
                const SizedBox(width: 6),
                FilterChip(
                  avatar: Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: _dateFilter != null ? cs.onPrimaryContainer : null,
                  ),
                  label: Text(
                    _dateFilter != null
                        ? DateFormat('MMM d').format(_dateFilter!)
                        : 'Date',
                  ),
                  selected: _dateFilter != null,
                  selectedColor: cs.primaryContainer,
                  onSelected: (_) => _pickDate(),
                  onDeleted: _dateFilter != null
                      ? () => setState(() => _dateFilter = null)
                      : null,
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
                        style: tt.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(_usageProvider(_filter)),
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
                        .where((e) =>
                            e['status']?.toString() == _statusFilter)
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

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_list_off,
                            size: 48, color: cs.outlineVariant),
                        const SizedBox(height: 12),
                        Text('No events match filters',
                            style: tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(_usageProvider(_filter)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      final ts = e['timestamp']?.toString() ?? '';
                      final date = ts.length > 19 ? ts.substring(0, 19) : ts;
                      final status = e['status']?.toString() ?? 'unknown';
                      final isOk = status == 'ok';
                      final statusColor = isOk
                          ? AppColors.success
                          : status == 'error'
                              ? cs.error
                              : cs.onSurfaceVariant;
                      final duration = e['duration_ms'];
                      final durationStr =
                          duration != null ? '${duration}ms' : '';

                      return Card(
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              e['interface']?.toString() ?? 'API',
                              style: tt.labelSmall
                                  ?.copyWith(color: cs.onPrimaryContainer),
                            ),
                          ),
                          title: Text(
                            e['action']?.toString() ?? '-',
                            style: tt.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
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
                              isOk ? 'ok' : status,
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
