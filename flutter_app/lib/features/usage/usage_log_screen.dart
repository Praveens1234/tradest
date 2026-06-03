import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/app_scaffold.dart';

final _usageProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient.instance.get<List<dynamic>>('/usage/events', params: {'limit': 100});
  return (response.data ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

class UsageLogScreen extends ConsumerWidget {
  const UsageLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(_usageProvider);

    return AppScaffold(
      title: 'Usage Log',
      body: usageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Color(0xFFEF4444)))),
        data: (events) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(_usageProvider),
          child: events.isEmpty
              ? const Center(child: Text('No events yet', style: TextStyle(color: Color(0xFF9CA3AF))))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final e = events[i];
                    final ts = e['timestamp']?.toString() ?? '';
                    final date = ts.length > 19 ? ts.substring(0, 19) : ts;
                    final status = e['status']?.toString() ?? 'unknown';
                    final statusColor = status == 'success'
                        ? const Color(0xFF22C55E)
                        : status == 'error'
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF9CA3AF);

                    return Card(
                      child: ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            e['interface']?.toString() ?? 'API',
                            style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          e['action']?.toString() ?? '-',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(date, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                        trailing: Text(
                          status,
                          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
