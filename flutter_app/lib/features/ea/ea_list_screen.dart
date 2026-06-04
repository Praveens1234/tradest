import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/shimmer_loading.dart';
import 'compile_log_sheet.dart';
import 'ea_provider.dart';
import 'ea_upload_sheet.dart';

class EAListScreen extends ConsumerStatefulWidget {
  const EAListScreen({super.key});

  @override
  ConsumerState<EAListScreen> createState() => _EAListScreenState();
}

class _EAListScreenState extends ConsumerState<EAListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final eaListAsync = ref.watch(eaListProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'EA Manager',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New EA'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SearchBar(
              hintText: 'Search EAs...',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _search = v),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: eaListAsync.when(
              loading: () => const ShimmerList(count: 5),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: cs.error, size: 48),
                      const SizedBox(height: 12),
                      Text(ApiClient.extractError(e),
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(eaListProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (eas) {
                final filtered = _search.isEmpty
                    ? eas
                    : eas
                        .where((e) => e.name
                            .toLowerCase()
                            .contains(_search.toLowerCase()))
                        .toList();

                if (filtered.isEmpty && eas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.code_off,
                            size: 64, color: cs.outlineVariant),
                        const SizedBox(height: 16),
                        Text('No EAs yet',
                            style: tt.titleMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Text('Tap + to create or upload one',
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
                        Icon(Icons.search_off,
                            size: 48, color: cs.outlineVariant),
                        const SizedBox(height: 12),
                        Text('No EAs matching "$_search"',
                            style: tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(eaListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final ea = filtered[i];
                      return Card(
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.fromLTRB(12, 4, 8, 4),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.code,
                                color: cs.onPrimaryContainer, size: 22),
                          ),
                          title: Text(ea.name,
                              style: tt.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${ea.type.toUpperCase()} · ${ea.path}',
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.build_outlined,
                                    color: cs.primary, size: 20),
                                tooltip: 'Compile',
                                onPressed: () => _compile(
                                    context, ea.id, ea.name),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: cs.error, size: 20),
                                tooltip: 'Delete',
                                onPressed: () => _confirmDelete(
                                    context, ref, ea.id, ea.name),
                              ),
                            ],
                          ),
                          onTap: () => context.push('/ea/${ea.id}'),
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

  void _showUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const EAUploadSheet(),
    ).then((_) {
      ref.invalidate(eaListProvider);
    });
  }

  void _compile(BuildContext context, int id, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, __) =>
            CompileLogSheet(eaId: id, eaName: name),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, int id, String name) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete EA'),
        content: Text('Delete "$name"? This moves it to trash.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.errorContainer,
              foregroundColor: cs.onErrorContainer,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(eaOperationsProvider.notifier)
                    .deleteEA(id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('EA deleted')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Delete failed: ${ApiClient.extractError(e)}'),
                    backgroundColor: cs.errorContainer,
                  ));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
