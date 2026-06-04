import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../shared/models/backtest_model.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/status_badge.dart';

class BacktestMonitorScreen extends ConsumerStatefulWidget {
  final int runId;
  const BacktestMonitorScreen({super.key, required this.runId});

  @override
  ConsumerState<BacktestMonitorScreen> createState() =>
      _BacktestMonitorScreenState();
}

class _BacktestMonitorScreenState extends ConsumerState<BacktestMonitorScreen> {
  BacktestRun? _run;
  WebSocketChannel? _channel;
  bool _loading = true;
  String? _error;
  final List<String> _logs = [];
  DateTime? _startTime;
  int? _elapsedS;
  double? _cpuPercent;
  double? _memoryMb;

  @override
  void initState() {
    super.initState();
    _fetchThenConnect();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _fetchThenConnect() async {
    await _fetchStatus();
    await _connectWs();
  }

  Future<void> _fetchStatus() async {
    try {
      final response = await ApiClient.instance
          .get<Map<String, dynamic>>('/backtest/${widget.runId}/status');
      if (mounted) {
        setState(() {
          _run = BacktestRun.fromJson(response.data ?? {});
          _loading = false;
          _error = null;
          if (_run?.startedAt != null) {
            _startTime = DateTime.tryParse(_run!.startedAt!);
          }
        });
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

  Future<void> _connectWs() async {
    if (_run?.status == 'done' ||
        _run?.status == 'failed' ||
        _run?.status == 'cancelled') return;

    try {
      final wsUrl =
          await ApiClient.buildWsUrl('/ws/backtest/${widget.runId}');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.stream.listen(
        (data) {
          if (!mounted) return;
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final update = BacktestRun.fromJson(json);

            // Extract resource telemetry from WS message
            final elapsedS = json['elapsed_s'] as int?;
            final resources = json['resources'] as Map?;
            final cpu = (resources?['cpu_percent'] as num?)?.toDouble();
            final mem = (resources?['memory_mb'] as num?)?.toDouble();

            // Build a meaningful log entry
            final errorMsg = json['error']?.toString();
            final logParts = <String>['Status: ${update.status}'];
            if (elapsedS != null) logParts.add('${elapsedS}s elapsed');
            if (cpu != null) logParts.add('CPU ${cpu.toStringAsFixed(1)}%');
            if (errorMsg != null) logParts.add('Error: $errorMsg');

            setState(() {
              _run = update;
              if (elapsedS != null) _elapsedS = elapsedS;
              if (cpu != null) _cpuPercent = cpu;
              if (mem != null) _memoryMb = mem;
              if (update.startedAt != null && _startTime == null) {
                _startTime = DateTime.tryParse(update.startedAt!);
              }
              _logs.add('${_timestamp()} ${logParts.join(' · ')}');
              if (_logs.length > 30) _logs.removeAt(0);
            });

            if (update.status == 'done' ||
                update.status == 'failed' ||
                update.status == 'cancelled') {
              _channel?.sink.close();
            }
          } catch (_) {
            if (mounted) {
              setState(() {
                _logs.add('${_timestamp()} $data');
                if (_logs.length > 30) _logs.removeAt(0);
              });
            }
          }
        },
        onDone: () {
          if (mounted &&
              _run?.status != 'done' &&
              _run?.status != 'failed' &&
              _run?.status != 'cancelled') {
            _fetchStatus();
          }
        },
        onError: (_) {
          if (mounted) _fetchStatus();
        },
      );
    } catch (_) {
      // WS unavailable — HTTP result suffices
    }
  }

  String _timestamp() {
    final now = DateTime.now();
    return '[${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}]';
  }

  String _elapsed() {
    // Prefer server-provided elapsed over wall-clock calculation
    if (_elapsedS != null) {
      final m = _elapsedS! ~/ 60;
      final s = _elapsedS! % 60;
      return m > 0 ? '${m}m ${s}s' : '${s}s';
    }
    if (_startTime == null) return '';
    final diff = DateTime.now().difference(_startTime!);
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
    return '${diff.inSeconds}s';
  }

  Future<void> _cancel() async {
    try {
      await ApiClient.instance
          .delete<dynamic>('/backtest/${widget.runId}/cancel');
      _fetchStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cancel failed: ${ApiClient.extractError(e)}'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Backtest #${widget.runId}',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _run == null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _fetchThenConnect,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final run = _run!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDone = run.status == 'done';
    final isFailed =
        run.status == 'failed' || run.status == 'cancelled';
    final isRunning =
        run.status == 'running' || run.status == 'pending';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  StatusBadge(status: run.status),
                  const Spacer(),
                  if (isRunning) ...[
                    Icon(Icons.timer_outlined,
                        size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    StreamBuilder<int>(
                      stream: Stream.periodic(
                          const Duration(seconds: 1), (i) => i),
                      builder: (_, __) => Text(
                        _elapsed(),
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ]),
                if (isRunning) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(cs.primary),
                      minHeight: 3,
                    ),
                  ),
                ],
                // Live resource telemetry
                if (isRunning &&
                    (_cpuPercent != null || _memoryMb != null)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_cpuPercent != null)
                        Expanded(
                          child: _ResourceMini(
                            label: 'CPU',
                            value: '${_cpuPercent!.toStringAsFixed(1)}%',
                            icon: Icons.memory,
                            color: _cpuPercent! > 80
                                ? cs.error
                                : AppColors.success,
                          ),
                        ),
                      if (_cpuPercent != null && _memoryMb != null)
                        const SizedBox(width: 8),
                      if (_memoryMb != null)
                        Expanded(
                          child: _ResourceMini(
                            label: 'RAM',
                            value: '${_memoryMb!.toStringAsFixed(0)} MB',
                            icon: Icons.storage,
                            color: cs.secondary,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _InfoRow('Run ID', '#${run.runId}'),
                if (run.eaId != null) _InfoRow('EA ID', '#${run.eaId}'),
                _InfoRow('Symbol',
                    run.parameters['symbol']?.toString() ?? '-'),
                _InfoRow(
                    'Period', run.parameters['period']?.toString() ?? '-'),
                _InfoRow(
                    'From', run.parameters['from_date']?.toString() ?? '-'),
                _InfoRow(
                    'To', run.parameters['to_date']?.toString() ?? '-'),
                if (run.startedAt != null)
                  _InfoRow(
                      'Started',
                      run.startedAt!.length > 19
                          ? run.startedAt!.substring(0, 19)
                          : run.startedAt!),
                if (run.finishedAt != null)
                  _InfoRow(
                      'Finished',
                      run.finishedAt!.length > 19
                          ? run.finishedAt!.substring(0, 19)
                          : run.finishedAt!),
              ],
            ),
          ),
        ),
        if (_logs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LIVE LOG',
                      style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.codeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _logs
                          .map((l) => Text(l,
                              style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                  fontSize: 11)))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (isDone)
          FilledButton.icon(
            onPressed: () => context.push('/results?runId=${run.runId}'),
            icon: const Icon(Icons.bar_chart),
            label: const Text('View Results',
                style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        if (isRunning)
          OutlinedButton.icon(
            onPressed: _cancel,
            icon: Icon(Icons.stop, color: cs.error),
            label:
                Text('Cancel Backtest', style: TextStyle(color: cs.error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        if (isFailed)
          FilledButton.tonal(
            onPressed: () => context.go('/backtest/setup'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh),
                  SizedBox(width: 8),
                  Text('Run Again', style: TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ResourceMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _ResourceMini({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant, fontSize: 9)),
              Text(value,
                  style: tt.labelSmall?.copyWith(
                      color: color, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style:
                  tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
        Expanded(
            child: Text(value,
                style: tt.bodySmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
