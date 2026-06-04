import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../shared/widgets/app_scaffold.dart';

class _LogEntry {
  final int id;
  final String level;
  final String loggerName;
  final String message;
  final Map<String, dynamic> context;
  final String timestamp;

  const _LogEntry({
    required this.id,
    required this.level,
    required this.loggerName,
    required this.message,
    required this.context,
    required this.timestamp,
  });

  factory _LogEntry.fromJson(Map<String, dynamic> j) => _LogEntry(
        id: j['id'] as int? ?? 0,
        level: j['level']?.toString() ?? 'INFO',
        loggerName: j['logger_name']?.toString() ?? '',
        message: j['message']?.toString() ?? '',
        context: (j['context'] as Map<String, dynamic>?) ?? {},
        timestamp: j['timestamp']?.toString() ?? '',
      );
}

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final List<_LogEntry> _entries = [];
  bool _loading = true;
  String? _error;
  bool _liveTail = false;
  bool _clearing = false;

  String? _levelFilter;
  final _loggerCtrl = TextEditingController();
  String _loggerFilter = '';

  WebSocketChannel? _wsChannel;
  final _scrollCtrl = ScrollController();

  static const _levels = ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    _scrollCtrl.dispose();
    _loggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{'limit': 200};
      if (_levelFilter != null) params['level'] = _levelFilter;
      if (_loggerFilter.isNotEmpty) params['logger'] = _loggerFilter;

      final response = await ApiClient.instance
          .get<List<dynamic>>('/logs/recent', params: params);
      final entries = (response.data ?? [])
          .map((e) =>
              _LogEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (mounted) {
        setState(() {
          _entries.clear();
          // API returns newest-first; reverse for chronological display
          _entries.addAll(entries.reversed);
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiClient.extractError(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleLiveTail() async {
    if (_liveTail) {
      _wsChannel?.sink.close();
      _wsChannel = null;
      setState(() => _liveTail = false);
    } else {
      setState(() => _liveTail = true);
      try {
        final wsUrl = await ApiClient.buildWsUrl('/ws/logs');
        _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
        _wsChannel!.stream.listen(
          _onWsMessage,
          onDone: () {
            if (mounted) setState(() => _liveTail = false);
          },
          onError: (_) {
            if (mounted) setState(() => _liveTail = false);
          },
        );
      } catch (_) {
        if (mounted) setState(() => _liveTail = false);
      }
    }
  }

  void _onWsMessage(dynamic data) {
    if (!mounted) return;
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final entry = _LogEntry.fromJson(json);
      // Apply client-side filters to live entries
      if (_levelFilter != null && entry.level != _levelFilter) return;
      if (_loggerFilter.isNotEmpty &&
          !entry.loggerName
              .toLowerCase()
              .contains(_loggerFilter.toLowerCase())) return;
      setState(() => _entries.add(entry));
      _scrollToBottom();
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text(
            'This will permanently delete all platform log entries. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      await ApiClient.instance.delete<dynamic>('/logs/clear');
      if (mounted) {
        setState(() {
          _entries.clear();
          _clearing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logs cleared')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _clearing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: ${ApiClient.extractError(e)}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ));
      }
    }
  }

  Color _levelColor(BuildContext context, String level) {
    final cs = Theme.of(context).colorScheme;
    return switch (level) {
      'DEBUG' => cs.onSurfaceVariant,
      'INFO' => cs.primary,
      'WARNING' => AppColors.warning,
      'ERROR' => cs.error,
      'CRITICAL' => cs.error,
      _ => cs.onSurface,
    };
  }

  Color _levelBg(BuildContext context, String level) {
    final cs = Theme.of(context).colorScheme;
    return switch (level) {
      'WARNING' => AppColors.warningDim,
      'ERROR' => cs.errorContainer.withAlpha(60),
      'CRITICAL' => cs.errorContainer.withAlpha(100),
      _ => cs.surfaceContainerHighest.withAlpha(60),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Platform Logs',
      actions: [
        if (_clearing)
          const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all logs',
            onPressed: _clearLogs,
          ),
        IconButton(
          icon: Icon(
            _liveTail ? Icons.wifi : Icons.wifi_off_outlined,
            color: _liveTail ? AppColors.success : null,
          ),
          tooltip: _liveTail ? 'Stop live tail' : 'Start live tail',
          onPressed: _toggleLiveTail,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _fetch,
        ),
      ],
      body: Column(
        children: [
          // Level filter chips
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _levelFilter == null,
                    onSelected: (_) {
                      setState(() => _levelFilter = null);
                      _fetch();
                    },
                  ),
                  const SizedBox(width: 6),
                  ..._levels.map((lvl) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(lvl),
                          selected: _levelFilter == lvl,
                          selectedColor:
                              _levelColor(context, lvl).withAlpha(40),
                          checkmarkColor: _levelColor(context, lvl),
                          labelStyle: _levelFilter == lvl
                              ? TextStyle(
                                  color: _levelColor(context, lvl),
                                  fontWeight: FontWeight.w600)
                              : null,
                          onSelected: (sel) {
                            setState(
                                () => _levelFilter = sel ? lvl : null);
                            _fetch();
                          },
                        ),
                      )),
                ],
              ),
            ),
          ),
          // Logger name filter
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _loggerCtrl,
              decoration: const InputDecoration(
                hintText: 'Filter by logger name...',
                prefixIcon: Icon(Icons.filter_list, size: 18),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) {
                setState(() => _loggerFilter = v);
                _fetch();
              },
            ),
          ),
          // Live tail banner
          if (_liveTail)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.success.withAlpha(80)),
              ),
              child: Row(
                children: [
                  _BlinkingDot(color: AppColors.success),
                  const SizedBox(width: 8),
                  Text('Live tail active',
                      style: tt.bodySmall
                          ?.copyWith(color: AppColors.success)),
                  const Spacer(),
                  Text('${_entries.length} entries',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          Expanded(child: _buildBody(cs, tt)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, TextTheme tt) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: cs.error, size: 48),
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                      tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.list_alt_outlined,
                size: 64, color: cs.outlineVariant),
            const SizedBox(height: 16),
            Text('No log entries',
                style:
                    tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Start live tail to see entries in real time',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: _entries.length,
      itemBuilder: (context, i) => _buildEntry(_entries[i], cs, tt),
    );
  }

  Widget _buildEntry(_LogEntry entry, ColorScheme cs, TextTheme tt) {
    final color = _levelColor(context, entry.level);
    final bg = _levelBg(context, entry.level);
    final ts = entry.timestamp.length > 19
        ? entry.timestamp.substring(0, 19)
        : entry.timestamp;
    final isCritical = entry.level == 'CRITICAL';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: (entry.level == 'ERROR' || isCritical)
            ? Border.all(color: color.withAlpha(60))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.level,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.loggerName,
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                    fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              ts,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                  fontFamily: 'monospace'),
            ),
          ]),
          const SizedBox(height: 5),
          SelectableText(
            entry.message,
            style: TextStyle(
              fontSize: 12,
              color: isCritical ? color : cs.onSurface,
              fontFamily: 'monospace',
            ),
          ),
          if (entry.context.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              entry.context.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join(' · '),
              style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                  fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final Color color;
  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withAlpha(
                (_ctrl.value * 200 + 55).round().clamp(0, 255)),
          ),
        ),
      );
}
