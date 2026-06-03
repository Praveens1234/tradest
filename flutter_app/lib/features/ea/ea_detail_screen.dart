import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../shared/models/ea_model.dart';
import '../../shared/widgets/app_scaffold.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eaAsync = ref.watch(_eaDetailProvider(widget.eaId));

    return eaAsync.when(
      loading: () => AppScaffold(
        title: 'EA Detail',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'EA Detail',
        body: Center(child: Text('Error: $e', style: const TextStyle(color: Color(0xFFEF4444)))),
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
                      padding: EdgeInsets.all(16),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(
                        onPressed: () => setState(() => _isEditing = false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => _save(ea.id),
                        child: const Text('Save', style: TextStyle(color: Color(0xFF22C55E))),
                      ),
                    ])
            else
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  _codeCtrl.text = ea.content ?? '';
                  setState(() => _isEditing = true);
                },
              ),
          ],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF111827),
                child: Row(children: [
                  _InfoChip(label: ea.type.toUpperCase()),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ea.path, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text(ea.updatedAt.length > 10 ? ea.updatedAt.substring(0, 10) : ea.updatedAt,
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                ]),
              ),
              Expanded(
                child: _isEditing
                    ? Container(
                        color: const Color(0xFF0D1117),
                        child: TextField(
                          controller: _codeCtrl,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFFE5E7EB)),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                            fillColor: Color(0xFF0D1117),
                            filled: true,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Container(
                          width: double.infinity,
                          color: const Color(0xFF0D1117),
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(
                            ea.content ?? '(empty)',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFFE5E7EB)),
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

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold)),
      );
}
