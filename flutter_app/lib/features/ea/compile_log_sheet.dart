import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';

enum _EntryType { error, warning }

class _CompileEntry {
  final _EntryType type;
  final String message;
  final String? file;
  final int? line;
  final int? col;

  const _CompileEntry({
    required this.type,
    required this.message,
    this.file,
    this.line,
    this.col,
  });
}

class CompileLogSheet extends ConsumerStatefulWidget {
  final int eaId;
  final String eaName;

  const CompileLogSheet({
    super.key,
    required this.eaId,
    required this.eaName,
  });

  @override
  ConsumerState<CompileLogSheet> createState() => _CompileLogSheetState();
}

class _CompileLogSheetState extends ConsumerState<CompileLogSheet> {
  WebSocketChannel? _channel;
  final List<_CompileEntry> _entries = [];
  bool _compiling = true;
  bool _done = false;
  String? _finalStatus;
  int _errorCount = 0;
  int _warningCount = 0;
  final DateTime _startTime = DateTime.now();
  bool _wsReceivedComplete = false;

  @override
  void initState() {
    super.initState();
    _connectAndCompile();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _connectAndCompile() async {
    // Connect WS first so we don't miss any messages
    try {
      final wsUrl =
          await ApiClient.buildWsUrl('/ws/compile/${widget.eaId}');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.stream.listen(
        _onWsMessage,
        onDone: _onWsDone,
        onError: (_) {},
      );
    } catch (_) {
      // WS unavailable — HTTP response will provide results
    }

    // Trigger compile via HTTP
    try {
      final response = await ApiClient.instance
          .post<Map<String, dynamic>>('/ea/${widget.eaId}/compile');
      if (!_wsReceivedComplete) {
        _processHttpResult(response.data ?? {});
      }
    } catch (e) {
      if (mounted && !_done) {
        setState(() {
          _compiling = false;
          _done = true;
          _finalStatus = 'error';
          _errorCount = 1;
          _entries.add(_CompileEntry(
            type: _EntryType.error,
            message: ApiClient.extractError(e),
          ));
        });
      }
    }
  }

  void _onWsMessage(dynamic data) {
    if (!mounted) return;
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final type = json['type']?.toString();

      if (type == 'complete') {
        _wsReceivedComplete = true;
        final status = json['status']?.toString() ?? 'error';
        final errors = _entries.where((e) => e.type == _EntryType.error).length;
        final warnings =
            _entries.where((e) => e.type == _EntryType.warning).length;
        setState(() {
          _compiling = false;
          _done = true;
          _finalStatus = status;
          _errorCount = errors;
          _warningCount = warnings;
        });
        _channel?.sink.close();
      } else if (type == 'error') {
        setState(() {
          _entries.add(_CompileEntry(
            type: _EntryType.error,
            message: json['message']?.toString() ?? '',
            file: json['file']?.toString(),
            line: json['line'] as int?,
            col: json['col'] as int?,
          ));
        });
      } else if (type == 'warning') {
        setState(() {
          _entries.add(_CompileEntry(
            type: _EntryType.warning,
            message: json['message']?.toString() ?? '',
            file: json['file']?.toString(),
            line: json['line'] as int?,
            col: json['col'] as int?,
          ));
        });
      }
    } catch (_) {}
  }

  void _onWsDone() {
    if (!mounted || _done) return;
    setState(() {
      _compiling = false;
      _done = true;
    });
  }

  void _processHttpResult(Map<String, dynamic> data) {
    if (!mounted) return;
    final status = data['status']?.toString() ?? 'error';
    final errorsRaw = data['errors'] as List? ?? [];
    final warningsRaw = data['warnings'] as List? ?? [];

    setState(() {
      _compiling = false;
      _done = true;
      _finalStatus = status;
      _errorCount = errorsRaw.length;
      _warningCount = warningsRaw.length;

      // Only add entries if WS didn't already populate them
      if (_entries.isEmpty) {
        for (final e in errorsRaw) {
          if (e is Map) {
            _entries.add(_CompileEntry(
              type: _EntryType.error,
              message: e['message']?.toString() ?? '',
              file: e['file']?.toString(),
              line: e['line'] as int?,
              col: e['col'] as int?,
            ));
          }
        }
        for (final w in warningsRaw) {
          if (w is Map) {
            _entries.add(_CompileEntry(
              type: _EntryType.warning,
              message: w['message']?.toString() ?? '',
              file: w['file']?.toString(),
              line: w['line'] as int?,
              col: w['col'] as int?,
            ));
          }
        }
      }
    });
  }

  String get _elapsedStr {
    final diff = DateTime.now().difference(_startTime);
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
    }
    return '${diff.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final success =
        _finalStatus == 'success' || _finalStatus == 'warning';

    return Column(
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              if (_compiling)
                _BlinkingDot(color: cs.primary)
              else
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success ? AppColors.success : cs.error,
                  size: 20,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _compiling
                      ? 'Compiling ${widget.eaName}…'
                      : success
                          ? 'Compiled: ${widget.eaName}'
                          : 'Compile Failed: ${widget.eaName}',
                  style: tt.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_compiling)
                StreamBuilder<int>(
                  stream:
                      Stream.periodic(const Duration(seconds: 1), (i) => i),
                  builder: (_, __) => Text(
                    _elapsedStr,
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
        // Summary banner
        if (_done && _finalStatus != null) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: success
                  ? AppColors.success.withAlpha(25)
                  : cs.errorContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: success
                    ? AppColors.success.withAlpha(80)
                    : cs.error.withAlpha(80),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  success
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  size: 16,
                  color: success ? AppColors.success : cs.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_errorCount error${_errorCount != 1 ? 's' : ''} · '
                    '$_warningCount warning${_warningCount != 1 ? 's' : ''}  '
                    '[${success ? 'Done' : 'Failed'} in $_elapsedStr]',
                    style: tt.bodySmall?.copyWith(
                      color: success ? AppColors.success : cs.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Divider(color: cs.outlineVariant, height: 1),
        Expanded(
          child: _entries.isEmpty && _compiling
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: cs.primary),
                      ),
                      const SizedBox(height: 12),
                      Text('Running MetaEditor…',
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : _entries.isEmpty && _done
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppColors.success, size: 48),
                            const SizedBox(height: 8),
                            Text('Compiled successfully',
                                style: tt.bodyMedium?.copyWith(
                                    color: AppColors.success)),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _entries.length,
                      itemBuilder: (context, i) =>
                          _buildEntry(_entries[i], cs, tt),
                    ),
        ),
        if (_done)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEntry(
      _CompileEntry entry, ColorScheme cs, TextTheme tt) {
    final isError = entry.type == _EntryType.error;
    final color = isError ? cs.error : AppColors.warning;
    final bgColor = isError
        ? cs.errorContainer.withAlpha(60)
        : AppColors.warningDim;
    final location =
        (entry.file != null && entry.line != null)
            ? '${entry.file}(${entry.line},${entry.col ?? 0})'
            : entry.file;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline
                    : Icons.warning_amber_outlined,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isError ? 'ERROR' : 'WARNING',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            entry.message,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          if (location != null) ...[
            const SizedBox(height: 3),
            Text(
              location,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color
              .withAlpha((_ctrl.value * 200 + 55).round().clamp(0, 255)),
        ),
      ),
    );
  }
}
