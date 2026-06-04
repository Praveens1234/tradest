import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/shimmer_loading.dart';

// Simple file node model
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
    final ext = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : null;
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

class FileBrowserScreen extends ConsumerStatefulWidget {
  const FileBrowserScreen({super.key});

  @override
  ConsumerState<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends ConsumerState<FileBrowserScreen> {
  String _currentPath = '';
  final List<String> _breadcrumbs = [];

  void _navigate(String path) {
    setState(() {
      _currentPath = path;
      _breadcrumbs.add(path);
    });
  }

  void _navigateUp() {
    if (_breadcrumbs.isNotEmpty) {
      _breadcrumbs.removeLast();
      setState(() {
        _currentPath = _breadcrumbs.isNotEmpty ? _breadcrumbs.last : '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filesAsync = ref.watch(_fileListProvider(_currentPath));

    return AppScaffold(
      title: 'File Browser',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_outlined),
          onPressed: () => ref.invalidate(_fileListProvider(_currentPath)),
        ),
      ],
      body: Column(
        children: [
          // Breadcrumb bar
          if (_breadcrumbs.isNotEmpty)
            Container(
              color: cs.surfaceContainer,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _breadcrumbs.clear();
                          _currentPath = '';
                        });
                      },
                      child: Text('root',
                          style: tt.bodySmall?.copyWith(color: cs.primary)),
                    ),
                    ..._breadcrumbs.map((crumb) {
                      final label = crumb.contains('/')
                          ? crumb.split('/').last
                          : crumb;
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
                                    final idx =
                                        _breadcrumbs.indexOf(crumb);
                                    setState(() {
                                      _breadcrumbs
                                          .removeRange(idx + 1, _breadcrumbs.length);
                                      _currentPath = crumb;
                                    });
                                  },
                            child: Text(
                              label,
                              style: tt.bodySmall?.copyWith(
                                color: isLast
                                    ? cs.onSurface
                                    : cs.primary,
                                fontWeight: isLast
                                    ? FontWeight.w600
                                    : null,
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
          Expanded(
            child: filesAsync.when(
              loading: () => const ShimmerList(count: 8),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: cs.error, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      ApiClient.extractError(e),
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
                        Icon(Icons.folder_open_outlined,
                            size: 48, color: cs.outlineVariant),
                        const SizedBox(height: 12),
                        Text('Empty directory',
                            style: tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  );
                }

                // Sort: directories first, then files alphabetically
                final sorted = [...items]..sort((a, b) {
                    if (a.isDir && !b.isDir) return -1;
                    if (!a.isDir && b.isDir) return 1;
                    return a.name.compareTo(b.name);
                  });

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(_fileListProvider(_currentPath)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, i) {
                      final node = sorted[i];
                      return _FileListTile(
                        node: node,
                        onNavigate: node.isDir ? () => _navigate(node.path) : null,
                        onViewFile: !node.isDir
                            ? () => _viewFile(context, node)
                            : null,
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

  Future<void> _viewFile(BuildContext context, _FileNode node) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FileViewSheet(node: node),
    );
  }
}

class _FileListTile extends StatelessWidget {
  final _FileNode node;
  final VoidCallback? onNavigate;
  final VoidCallback? onViewFile;

  const _FileListTile({
    required this.node,
    this.onNavigate,
    this.onViewFile,
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
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
