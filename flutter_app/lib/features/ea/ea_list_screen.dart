import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'ea_provider.dart';

class EAListScreen extends ConsumerWidget {
  const EAListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eaListAsync = ref.watch(eaListProvider);
    final ops = ref.watch(eaOperationsProvider);

    return AppScaffold(
      title: 'EA Manager',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New EA'),
      ),
      body: eaListAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 12),
              Text(e.toString(), style: const TextStyle(color: Color(0xFF9CA3AF))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(eaListProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (eas) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(eaListProvider),
          child: eas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.code_off, size: 64, color: Color(0xFF374151)),
                      const SizedBox(height: 16),
                      const Text('No EAs yet', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('Tap + to create one', style: TextStyle(color: Color(0xFF6B7280))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: eas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final ea = eas[i];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.code, color: Color(0xFF3B82F6), size: 20),
                        ),
                        title: Text(ea.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${ea.type.toUpperCase()} • ${ea.path}',
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: ops.isLoading
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.play_circle_outline, color: Color(0xFF3B82F6)),
                              tooltip: 'Compile',
                              onPressed: ops.isLoading ? null : () => _compile(context, ref, ea.id, ea.name),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
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
        ),
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
        backgroundColor: const Color(0xFF1F2937),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
        content: Text('Compile error: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete EA'),
        content: Text('Delete "$name"? This moves it to trash.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
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
                    content: Text('Delete failed: $e'),
                    backgroundColor: const Color(0xFFEF4444),
                  ));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
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
                decoration: const InputDecoration(labelText: 'EA Name', hintText: 'MyExpert'),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              try {
                await ref.read(eaOperationsProvider.notifier)
                    .createEA(name: nameCtrl.text.trim(), content: contentCtrl.text, type: 'mq5');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('EA created')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Create failed: $e'),
                    backgroundColor: const Color(0xFFEF4444),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.success ? 'Compiled: $eaName' : 'Compile Errors: $eaName',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              if (result.errors.isNotEmpty) ...[
                const Text('ERRORS', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                ...result.errors.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0000),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444).withAlpha(77)),
                  ),
                  child: Text(e, style: const TextStyle(color: Color(0xFFEF4444), fontFamily: 'monospace', fontSize: 12)),
                )),
                const SizedBox(height: 16),
              ],
              if (result.warnings.isNotEmpty) ...[
                const Text('WARNINGS', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                ...result.warnings.map((w) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1200),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(w, style: const TextStyle(color: Color(0xFFF59E0B), fontFamily: 'monospace', fontSize: 12)),
                )),
              ],
              if (result.output != null && result.output!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('LOG', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(result.output!, style: const TextStyle(color: Color(0xFF9CA3AF), fontFamily: 'monospace', fontSize: 11)),
                ),
              ],
              if (result.success && result.errors.isEmpty && result.warnings.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, color: Color(0xFF22C55E), size: 48),
                        SizedBox(height: 8),
                        Text('Compiled successfully', style: TextStyle(color: Color(0xFF22C55E))),
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
