import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/storage_service.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/shimmer_loading.dart';

class _FileNode {
  final String name;
  final String path;
  final bool isDir;
  final String? extension;
  final int? size;

  const _FileNode({
    required this.name,
    required this.path,
    required this.isDir,
    this.extension,
    this.size,
  });

  factory _FileNode.fromJson(Map<String, dynamic> json) {
    final path = json['path']?.toString() ?? json['name']?.toString() ?? '';
    final name = path.contains('/') ? path.split('/').last : path;
    final isDir = json['is_dir'] as bool? ?? json['type'] == 'directory';
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : null;
    return _FileNode(
      name: name,
      path: path,
      isDir: isDir,
      extension: ext,
      size: json['size'] as int?,
    );
  }
}

final _fileListProvider =
    FutureProvider.family.autoDispose<List<_FileNode>, String>((ref, path) async {
  final response = await ApiClient.instance.get<List<dynamic>>(
    '/files/list',
    params: {'path': path},
  );
  return (response.data ?? [])
      .map((e) => _FileNode.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

final _fileSearchProvider = FutureProvider.family
    .autoDispose<List<_FileNode>, ({String query, String path})>(
        (ref, args) async {
  final response = await ApiClient.instance.get<List<dynamic>>(
    '/files/search',
    params: {'q': args.query, if (args.path.isNotEmpty) 'path': args.path},
  );
  return (response.data ?? [])
      .map((e) => _FileNode.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

class FileBrowserScreen extends ConsumerStatefulWidget {
  const FileBrowserScreen({super.key});

  @override
  ConsumerState<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends ConsumerState<FileBrowserScreen> {
  String _currentPath = '';
  final List<String> _breadcrumbs = [];
  bool _searching = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _navigate(String path) {
    setState(() {
      _currentPath = path;
      _breadcrumbs.add(path);
      _searching = false;
      _searchQuery = '';
      _searchCtrl.clear();
    });
  }

  void _startSearch() => setState(() => _searching = true);

  void _stopSearch() {
    setState(() {
      _searching = false;
      _searchQuery = '';
      _searchCtrl.clear();
    });
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
      });
      await ApiClient.instance.post<dynamic>(
        '/files/upload',
        data: formData,
        params: {'path': _currentPath, 'override': false},
      );
      ref.invalidate(_fileListProvider(_currentPath));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Uploaded ${file.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: ${ApiClient.extractError(e)}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ));
      }
    }
  }

  Future<void> _mkdir() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: ctrl,
          decoration:
              const InputDecoration(labelText: 'Folder name', hintText: 'NewFolder'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;

    final fullPath = _currentPath.isEmpty ? result : '$_currentPath/$result';
    try {
      await ApiClient.instance.post<dynamic>('/files/mkdir', data: {'path': fullPath});
      ref.invalidate(_fileListProvider(_currentPath));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Created $result')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: ${ApiClient.extractError(e)}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ));
      }
    }
  }

  Future<void> _showContextMenu(BuildContext context, _FileNode node) async {
    final serverUrl = await StorageService.instance.getServerUrl();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FileContextMenu(
        node: node,
        onView: node.isDir ? null : () => _viewFile(context, node),
        onDownload: node.isDir
            ? null
            : () => _openUrl(
                '$serverUrl/files/download?path=${Uri.encodeComponent(node.path)}'),
        onDownloadZip: node.isDir
            ? () => _openUrl(
                '$serverUrl/files/download-zip?path=${Uri.encodeComponent(node.path)}')
            : null,
        onRename: () => _rename(context, node),
        onDelete: () => _delete(context, node),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _rename(BuildContext context, _FileNode node) async {
    final ctrl = TextEditingController(text: node.name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: 'New name', hintText: node.name),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Rename')),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == node.name) return;

    try {
      await ApiClient.instance.put<dynamic>(
        '/files/rename',
        data: {'path': node.path, 'new_name': result, 'override': false},
      );
      ref.invalidate(_fileListProvider(_currentPath));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Renamed to $result')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Rename failed: ${ApiClient.extractError(e)}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ));
      }
    }
  }

  Future<void> _delete(BuildContext context, _FileNode node) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${node.isDir ? 'Folder' : 'File'}'),
        content: Text('Move "${node.name}" to trash?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.errorContainer,
              foregroundColor: cs.onErrorContainer,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient.instance.delete<dynamic>(
        '/files/delete',
        data: {'path': node.path, 'soft': true},
      );
      ref.invalidate(_fileListProvider(_currentPath));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Moved ${node.name} to trash')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: ${ApiClient.extractError(e)}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final listAsync = _searching && _searchQuery.length >= 2
        ? ref.watch(
            _fileSearchProvider((query: _searchQuery, path: _currentPath)))
        : ref.watch(_fileListProvider(_currentPath));

    return AppScaffold(
      title: 'File Browser',
      actions: [
        if (_searching)
          IconButton(icon: const Icon(Icons.close), onPressed: _stopSearch)
        else ...[
          IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'New folder',
            onPressed: _mkdir,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.invalidate(_fileListProvider(_currentPath)),
          ),
        ],
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadFile,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      body: Column(
        children: [
          if (_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SearchBar(
                controller: _searchCtrl,
                hintText: 'Search files…',
                leading: const Icon(Icons.search),
                onChanged: (v) => setState(() => _searchQuery = v),
                autoFocus: true,
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
              ),
            ),
          if (_breadcrumbs.isNotEmpty && !_searching)
            Container(
              color: cs.surfaceContainer,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() {
                        _breadcrumbs.clear();
                        _currentPath = '';
                      }),
                      child: Text('root',
                          style: tt.bodySmall?.copyWith(color: cs.primary)),
                    ),
                    ..._breadcrumbs.map((crumb) {
                      final label =
                          crumb.contains('/') ? crumb.split('/').last : crumb;
                      final isLast = crumb == _breadcrumbs.last;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_right,
                              size: 14, color: cs.onSurfaceVariant),
                          InkWell(
                            onTap: isLast
                                ? null
                                : () {
                                    final idx = _breadcrumbs.indexOf(crumb);
                                    setState(() {
                                      _breadcrumbs.removeRange(
                                          idx + 1, _breadcrumbs.length);
                                      _currentPath = crumb;
                                    });
                                  },
                            child: Text(
                              label,
                              style: tt.bodySmall?.copyWith(
                                color: isLast ? cs.onSurface : cs.primary,
                                fontWeight:
                                    isLast ? FontWeight.w600 : null,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          if (_searching && _searchQuery.length < 2)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 48, color: cs.outlineVariant),
                    const SizedBox(height: 12),
                    Text('Type at least 2 characters to search',
                        style: tt.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: listAsync.when(
                loading: () => const ShimmerList(count: 8),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: cs.error, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        ApiClient.extractError(e),
                        style: tt.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            ref.invalidate(_fileListProvider(_currentPath)),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _searching
                                ? Icons.search_off
                                : Icons.folder_open_outlined,
                            size: 48,
                            color: cs.outlineVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searching
                                ? 'No files found for "$_searchQuery"'
                                : 'Empty directory',
                            style: tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  }

                  final sorted = [...items]..sort((a, b) {
                      if (a.isDir && !b.isDir) return -1;
                      if (!a.isDir && b.isDir) return 1;
                      return a.name.compareTo(b.name);
                    });

                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(_fileListProvider(_currentPath)),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, i) {
                        final node = sorted[i];
                        return _FileListTile(
                          node: node,
                          onNavigate:
                              node.isDir ? () => _navigate(node.path) : null,
                          onViewFile: !node.isDir
                              ? () => _viewFile(context, node)
                              : null,
                          onLongPress: () =>
                              _showContextMenu(context, node),
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

  Future<void> _viewFile(BuildContext context, _FileNode node) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FileViewSheet(node: node),
    );
  }
}

class _FileContextMenu extends StatelessWidget {
  final _FileNode node;
  final VoidCallback? onView;
  final VoidCallback? onDownload;
  final VoidCallback? onDownloadZip;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _FileContextMenu({
    required this.node,
    this.onView,
    this.onDownload,
    this.onDownloadZip,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    node.isDir ? Icons.folder : Icons.insert_drive_file,
                    color: node.isDir ? AppColors.warning : cs.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(node.name,
                        style: tt.titleSmall,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (onView != null)
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View'),
                onTap: () {
                  Navigator.pop(context);
                  onView!();
                },
              ),
            if (onDownload != null)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Download'),
                onTap: () {
                  Navigator.pop(context);
                  onDownload!();
                },
              ),
            if (onDownloadZip != null)
              ListTile(
                leading: const Icon(Icons.folder_zip_outlined),
                title: const Text('Download as ZIP'),
                onTap: () {
                  Navigator.pop(context);
                  onDownloadZip!();
                },
              ),
            if (onRename != null)
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(context);
                  onRename!();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text('Delete', style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FileListTile extends StatelessWidget {
  final _FileNode node;
  final VoidCallback? onNavigate;
  final VoidCallback? onViewFile;
  final VoidCallback? onLongPress;

  const _FileListTile({
    required this.node,
    this.onNavigate,
    this.onViewFile,
    this.onLongPress,
  });

  IconData get _icon {
    if (node.isDir) return Icons.folder;
    switch (node.extension) {
      case 'mq5':
      case 'mq4':
        return Icons.code;
      case 'ex5':
      case 'ex4':
        return Icons.memory;
      case 'html':
        return Icons.web;
      case 'csv':
        return Icons.table_chart;
      case 'xlsx':
      case 'xls':
        return Icons.table_rows;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _iconColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (node.isDir) return AppColors.warning;
    switch (node.extension) {
      case 'mq5':
      case 'mq4':
        return cs.primary;
      case 'ex5':
      case 'ex4':
        return AppColors.success;
      case 'html':
        return AppColors.warning;
      default:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: Icon(_icon, color: _iconColor(context), size: 22),
        title: Text(
          node.name,
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: node.size != null
            ? Text(_formatSize(node.size!),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
            : null,
        trailing: node.isDir
            ? Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 18)
            : Icon(Icons.visibility_outlined,
                color: cs.onSurfaceVariant, size: 18),
        onTap: onNavigate ?? onViewFile,
        onLongPress: onLongPress,
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _FileViewSheet extends StatelessWidget {
  final _FileNode node;
  const _FileViewSheet({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.code, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(node.name,
                        style: tt.titleSmall,
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Divider(color: cs.outlineVariant, height: 1),
          Expanded(
            child: FutureBuilder<String>(
              future: _loadContent(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      ApiClient.extractError(snap.error!),
                      style: tt.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  );
                }
                return SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    snap.data ?? '(empty)',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFFE5E7EB),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _loadContent() async {
    final response = await ApiClient.instance.get<dynamic>(
      '/files/read',
      params: {'path': node.path},
    );
    final data = response.data;
    if (data is String) return data;
    if (data is Map) return data['content']?.toString() ?? data.toString();
    return data?.toString() ?? '';
  }
}
