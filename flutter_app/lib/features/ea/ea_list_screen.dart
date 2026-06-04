import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/shimmer_loading.dart';
import 'ea_provider.dart';

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
    final ops = ref.watch(eaOperationsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'EA Manager',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
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
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
                        .where((e) =>
                            e.name.toLowerCase().contains(_search.toLowerCase()))
                        .toList();

                if (filtered.isEmpty && eas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.code_off, size: 64, color: cs.outlineVariant),
                        const SizedBox(height: 16),
                        Text('No EAs yet',
                            style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Text('Tap + to create one',
                            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: cs.outlineVariant),
                        const SizedBox(height: 12),
                        Text('No EAs matching "$_search"',
                            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
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
                          contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.code, color: cs.onPrimaryContainer, size: 22),
                          ),
                          title: Text(ea.name,
                              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${ea.type.toUpperCase()} • ${ea.path}',
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: ops.isLoading
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: cs.primary))
                                    : Icon(Icons.play_circle_outline,
                                        color: cs.primary),
                                tooltip: 'Compile',
                                onPressed: ops.isLoading
                                    ? null
                                    : () => _compile(context, ref, ea.id, ea.name),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: cs.error),
                                tooltip: 'Delete',
                                onPressed: () => _confirmDelete(context, ref, ea.id, ea.name),
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

  Future<void> _compile(BuildContext context, WidgetRef ref, int id, String name) async {
    try {
      final result = await ref.read(eaOperationsProvider.notifier).compileEA(id);
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => _CompileResultSheet(
            eaName: name,
            result: result,
            scrollController: controller,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Compile error: ${ApiClient.extractError(e)}'),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
      ));
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete EA'),
        content: Text('Delete "$name"? This moves it to trash.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.errorContainer,
              foregroundColor: cs.onErrorContainer,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(eaOperationsProvider.notifier).deleteEA(id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('EA deleted')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Delete failed: ${ApiClient.extractError(e)}'),
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

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final contentCtrl = TextEditingController(text: '''//+------------------------------------------------------------------+
//| Expert Advisor                                                   |
//+------------------------------------------------------------------+
#property strict

int OnInit() { return(INIT_SUCCEEDED); }
void OnDeinit(const int reason) {}
void OnTick() {}
''');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create New EA'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'EA Name', hintText: 'MyExpert'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                decoration: const InputDecoration(labelText: 'Initial Code'),
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              try {
                await ref.read(eaOperationsProvider.notifier).createEA(
                      name: nameCtrl.text.trim(),
                      content: contentCtrl.text,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('EA created')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Create failed: ${ApiClient.extractError(e)}'),
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                  ));
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _CompileResultSheet extends StatelessWidget {
  final String eaName;
  final CompileResult result;
  final ScrollController scrollController;

  const _CompileResultSheet({
    required this.eaName,
    required this.result,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: cs.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success ? AppColors.success : cs.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.success
                      ? 'Compiled: $eaName'
                      : 'Compile Errors: $eaName',
                  style: tt.titleMedium,
                ),
              ),
            ],
          ),
        ),
        Divider(color: cs.outlineVariant, height: 1),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              if (result.errors.isNotEmpty) ...[
                Text('ERRORS',
                    style: tt.labelSmall?.copyWith(
                        color: cs.error, letterSpacing: 1)),
                const SizedBox(height: 8),
                ...result.errors.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withAlpha(80),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: cs.error.withAlpha(80)),
                      ),
                      child: Text(e,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12)),
                    )),
                const SizedBox(height: 16),
              ],
              if (result.warnings.isNotEmpty) ...[
                Text('WARNINGS',
                    style: tt.labelSmall?.copyWith(
                        color: AppColors.warning, letterSpacing: 1)),
                const SizedBox(height: 8),
                ...result.warnings.map((w) => Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warningDim,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(w,
                          style: const TextStyle(
                              color: AppColors.warning,
                              fontFamily: 'monospace',
                              fontSize: 12)),
                    )),
              ],
              if (result.output != null && result.output!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('LOG',
                    style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant, letterSpacing: 1)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.codeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(result.output!,
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontFamily: 'monospace',
                          fontSize: 11)),
                ),
              ],
              if (result.success &&
                  result.errors.isEmpty &&
                  result.warnings.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: AppColors.success, size: 48),
                        const SizedBox(height: 8),
                        Text('Compiled successfully',
                            style: TextStyle(color: AppColors.success)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
