import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../shared/models/ea_model.dart';
import '../../shared/widgets/app_scaffold.dart';
import 'compile_log_sheet.dart';
import 'ea_provider.dart';

final _eaDetailProvider = FutureProvider.family.autoDispose<EAModel, int>((ref, id) async {
  final response = await ApiClient.instance.get<Map<String, dynamic>>('/ea/$id');
  return EAModel.fromJson(response.data ?? {});
});

class EADetailScreen extends ConsumerStatefulWidget {
  final int eaId;
  const EADetailScreen({super.key, required this.eaId});

  @override
  ConsumerState<EADetailScreen> createState() => _EADetailScreenState();
}

class _EADetailScreenState extends ConsumerState<EADetailScreen> {
  bool _isEditing = false;
  late TextEditingController _codeCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(int id) async {
    setState(() => _isSaving = true);
    try {
      await ApiClient.instance.put<dynamic>('/ea/$id', data: {'content': _codeCtrl.text});
      ref.invalidate(_eaDetailProvider(id));
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: ${ApiClient.extractError(e)}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        builder: (_, __) => CompileLogSheet(eaId: id, eaName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final eaAsync = ref.watch(_eaDetailProvider(widget.eaId));

    return eaAsync.when(
      loading: () => AppScaffold(
        title: 'EA Detail',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'EA Detail',
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: cs.error, size: 48),
              const SizedBox(height: 12),
              Text(ApiClient.extractError(e),
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(_eaDetailProvider(widget.eaId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (ea) {
        if (!_isEditing && _codeCtrl.text.isEmpty && ea.content != null) {
          _codeCtrl.text = ea.content!;
        }
        return AppScaffold(
          title: ea.name,
          actions: [
            if (_isEditing)
              _isSaving
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(
                        onPressed: () => setState(() => _isEditing = false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => _save(ea.id),
                        child: Text('Save',
                            style: TextStyle(color: AppColors.success)),
                      ),
                    ])
            else ...[
              IconButton(
                icon: const Icon(Icons.build_outlined),
                tooltip: 'Compile',
                onPressed: () => _compile(context, ea.id, ea.name),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: () {
                  _codeCtrl.text = ea.content ?? '';
                  setState(() => _isEditing = true);
                },
              ),
            ],
          ],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: cs.surfaceContainer,
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ea.type.toUpperCase(),
                      style: tt.labelSmall?.copyWith(color: cs.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ea.path,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ea.updatedAt.length > 10 ? ea.updatedAt.substring(0, 10) : ea.updatedAt,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ]),
              ),
              Expanded(
                child: _isEditing
                    ? Container(
                        color: AppColors.codeBg,
                        child: TextField(
                          controller: _codeCtrl,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: Color(0xFFE5E7EB)),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                            fillColor: AppColors.codeBg,
                            filled: true,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Container(
                          width: double.infinity,
                          color: AppColors.codeBg,
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(
                            ea.content ?? '(empty)',
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: Color(0xFFE5E7EB)),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
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
                  result.success ? 'Compiled: $eaName' : 'Compile Failed: $eaName',
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
                    style: tt.labelSmall?.copyWith(color: cs.error, letterSpacing: 1)),
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
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
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
              if (result.success && result.errors.isEmpty && result.warnings.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: AppColors.success, size: 48),
                        const SizedBox(height: 8),
                        const Text('Compiled successfully',
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
