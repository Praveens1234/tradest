import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import 'compile_log_sheet.dart';
import 'ea_provider.dart';

class EAUploadSheet extends ConsumerStatefulWidget {
  const EAUploadSheet({super.key});

  @override
  ConsumerState<EAUploadSheet> createState() => _EAUploadSheetState();
}

class _EAUploadSheetState extends ConsumerState<EAUploadSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Write Code tab
  final _nameCtrl = TextEditingController();
  final _contentCtrl = TextEditingController(text: '''//+------------------------------------------------------------------+
//| Expert Advisor                                                   |
//+------------------------------------------------------------------+
#property strict

int OnInit() { return(INIT_SUCCEEDED); }
void OnDeinit(const int reason) {}
void OnTick() {}
''');
  String _type = 'mq5';
  bool _compileAfterCreate = false;
  bool _creating = false;
  int? _createdId;
  String? _createdName;

  // Upload Files tab
  List<PlatformFile> _pickedFiles = [];
  bool _overrideFiles = false;
  bool _compileAfterUpload = false;
  bool _uploading = false;
  int _uploadedCount = 0;
  List<Map<String, dynamic>> _uploadResults = [];
  int? _uploadedEaId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mq5', 'mqh'],
      withData: true,
    );
    if (result != null && mounted) {
      setState(() {
        _pickedFiles = result.files;
        _uploadResults = [];
        _uploadedCount = 0;
        _uploadedEaId = null;
      });
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and code are required')),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/ea/create',
        data: {'name': name, 'content': _contentCtrl.text, 'type': _type},
      );
      final id = response.data?['id'] as int?;
      ref.invalidate(eaListProvider);

      if (mounted) {
        setState(() {
          _creating = false;
          _createdId = id;
          _createdName = name;
        });
        if (_compileAfterCreate && _type == 'mq5' && id != null) {
          _showCompileSheet(id, name);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Create failed: ${ApiClient.extractError(e)}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ));
      }
    }
  }

  Future<void> _uploadFiles() async {
    if (_pickedFiles.isEmpty) return;
    setState(() {
      _uploading = true;
      _uploadedCount = 0;
      _uploadResults = [];
      _uploadedEaId = null;
    });

    for (final file in _pickedFiles) {
      try {
        final bytes = file.bytes;
        if (bytes == null) {
          setState(() {
            _uploadResults.add({
              'name': file.name,
              'success': false,
              'error': 'Could not read file bytes',
            });
            _uploadedCount++;
          });
          continue;
        }

        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: file.name),
        });

        final response = await ApiClient.instance.post<Map<String, dynamic>>(
          '/ea/upload',
          data: formData,
          params: {'override': _overrideFiles},
        );

        final data = response.data ?? {};
        final uploadedId = data['id'] as int?;

        setState(() {
          _uploadResults.add({
            'name': data['name'] ?? file.name,
            'path': data['path'] ?? '',
            'id': uploadedId,
            'success': true,
          });
          _uploadedCount++;
          if (file.name.toLowerCase().endsWith('.mq5') &&
              uploadedId != null) {
            _uploadedEaId = uploadedId;
          }
        });
      } catch (e) {
        setState(() {
          _uploadResults.add({
            'name': file.name,
            'path': '',
            'success': false,
            'error': ApiClient.extractError(e),
          });
          _uploadedCount++;
        });
      }
    }

    if (mounted) {
      setState(() => _uploading = false);
      ref.invalidate(eaListProvider);

      if (_compileAfterUpload && _uploadedEaId != null) {
        final name = _uploadResults
                .where((r) => r['id'] == _uploadedEaId)
                .map((r) => r['name'] as String?)
                .firstOrNull ??
            'EA';
        _showCompileSheet(_uploadedEaId!, name ?? 'EA');
      }
    }
  }

  void _showCompileSheet(int eaId, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, __) =>
            CompileLogSheet(eaId: eaId, eaName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add_box_outlined,
                      color: cs.onPrimaryContainer, size: 20),
                ),
                const SizedBox(width: 12),
                Text('New Expert Advisor', style: tt.titleMedium),
              ],
            ),
          ),
          TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(icon: Icon(Icons.code, size: 18), text: 'Write Code'),
              Tab(
                  icon: Icon(Icons.upload_file, size: 18),
                  text: 'Upload Files'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildWriteTab(controller, cs, tt),
                _buildUploadTab(controller, cs, tt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWriteTab(
      ScrollController controller, ColorScheme cs, TextTheme tt) {
    if (_createdId != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 56),
              const SizedBox(height: 16),
              Text('EA created!',
                  style: tt.titleMedium
                      ?.copyWith(color: AppColors.success)),
              const SizedBox(height: 4),
              Text(_createdName ?? '',
                  style: tt.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'EA Name',
              hintText: 'MyExpert',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(
              labelText: 'File Type',
              prefixIcon: Icon(Icons.extension_outlined),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'mq5',
                  child: Text('.mq5 — Expert Advisor')),
              DropdownMenuItem(
                  value: 'mqh',
                  child: Text('.mqh — Include Header')),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'mq5'),
          ),
          const SizedBox(height: 12),
          Text('Source Code',
              style: tt.labelMedium
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.codeBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: TextField(
              controller: _contentCtrl,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFFE5E7EB),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
                fillColor: Colors.transparent,
                filled: false,
              ),
            ),
          ),
          if (_type == 'mq5') ...[
            const SizedBox(height: 4),
            CheckboxListTile(
              dense: true,
              title: const Text('Compile after create'),
              value: _compileAfterCreate,
              onChanged: (v) =>
                  setState(() => _compileAfterCreate = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _creating ? null : _create,
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.create),
              label: Text(_creating ? 'Creating…' : 'Create EA'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTab(
      ScrollController controller, ColorScheme cs, TextTheme tt) {
    final hasMq5 = _pickedFiles
        .any((f) => f.name.toLowerCase().endsWith('.mq5'));
    final uploadsDone =
        _uploadResults.isNotEmpty && !_uploading;

    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drop zone
          GestureDetector(
            onTap: _uploading ? null : _pickFiles,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _pickedFiles.isEmpty
                      ? cs.outlineVariant
                      : cs.primary,
                  width: _pickedFiles.isEmpty ? 1 : 2,
                ),
                borderRadius: BorderRadius.circular(12),
                color: cs.surfaceContainerHighest.withAlpha(40),
              ),
              child: Column(
                children: [
                  Icon(
                    _pickedFiles.isEmpty
                        ? Icons.upload_file
                        : Icons.check_circle_outline,
                    size: 36,
                    color: _pickedFiles.isEmpty
                        ? cs.onSurfaceVariant
                        : cs.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pickedFiles.isEmpty
                        ? 'Tap to select .mq5 or .mqh files'
                        : '${_pickedFiles.length} file(s) selected — tap to change',
                    style: tt.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Supports multiple files (1 EA + multiple headers)',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          // Selected files list
          if (_pickedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...List.generate(_pickedFiles.length, (i) {
              final file = _pickedFiles[i];
              final isMq5 =
                  file.name.toLowerCase().endsWith('.mq5');
              final Map<String, dynamic>? result =
                  i < _uploadResults.length
                      ? _uploadResults[i]
                      : null;
              final isUploading =
                  _uploading && i == _uploadedCount;

              Widget trailing;
              if (result != null) {
                trailing = result['success'] == true
                    ? const Icon(Icons.check_circle,
                        color: AppColors.success, size: 18)
                    : Icon(Icons.error_outline,
                        color: cs.error, size: 18);
              } else if (isUploading) {
                trailing = const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2),
                );
              } else {
                trailing = IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      setState(() => _pickedFiles.removeAt(i)),
                );
              }

              return ListTile(
                dense: true,
                leading: Icon(
                  isMq5
                      ? Icons.code
                      : Icons.insert_drive_file_outlined,
                  color: isMq5 ? cs.primary : AppColors.warning,
                  size: 20,
                ),
                title: Text(file.name, style: tt.bodySmall),
                subtitle: Text(
                  isMq5
                      ? 'Expert Advisor (.mq5)'
                      : 'Include header (.mqh)',
                  style: tt.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                trailing: trailing,
              );
            }),
          ],
          // Upload results — server file paths
          if (uploadsDone) ...[
            const SizedBox(height: 12),
            Text('FILE LOCATIONS',
                style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant, letterSpacing: 1)),
            const SizedBox(height: 8),
            ..._uploadResults.map((r) {
              final success = r['success'] == true;
              final label = success
                  ? (r['path'] as String? ?? r['name'] as String? ?? '')
                  : (r['error'] as String? ?? 'Upload failed');
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: success
                      ? AppColors.success.withAlpha(15)
                      : cs.errorContainer.withAlpha(60),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: success
                        ? AppColors.success.withAlpha(60)
                        : cs.error.withAlpha(60),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      success ? Icons.check : Icons.error_outline,
                      size: 14,
                      color:
                          success ? AppColors.success : cs.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        label,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            dense: true,
            title: const Text('Override existing files'),
            subtitle: Text(
              'Overwrite if file already exists on server',
              style: tt.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            value: _overrideFiles,
            onChanged: (v) =>
                setState(() => _overrideFiles = v),
            contentPadding: EdgeInsets.zero,
          ),
          if (hasMq5)
            CheckboxListTile(
              dense: true,
              title: const Text('Compile .mq5 after upload'),
              value: _compileAfterUpload,
              onChanged: (v) =>
                  setState(() => _compileAfterUpload = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_pickedFiles.isEmpty || _uploading)
                  ? null
                  : _uploadFiles,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_uploading
                  ? 'Uploading ${_uploadedCount + 1}/${_pickedFiles.length}…'
                  : uploadsDone
                      ? 'Upload Again'
                      : 'Upload ${_pickedFiles.length > 1 ? '${_pickedFiles.length} Files' : 'File'}'),
            ),
          ),
        ],
      ),
    );
  }
}
