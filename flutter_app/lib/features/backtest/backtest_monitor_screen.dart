import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../shared/models/backtest_model.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/status_badge.dart';

class BacktestMonitorScreen extends ConsumerStatefulWidget {
  final int runId;
  const BacktestMonitorScreen({super.key, required this.runId});

  @override
  ConsumerState<BacktestMonitorScreen> createState() => _BacktestMonitorScreenState();
}

class _BacktestMonitorScreenState extends ConsumerState<BacktestMonitorScreen> {
  BacktestRun? _run;
  Timer? _timer;
  bool _loading = true;
  String? _error;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _elapsed += 3;
      if (_run?.status != 'done' && _run?.status != 'failed' && _run?.status != 'cancelled') {
        _fetch();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final response = await ApiClient.instance.get<Map<String, dynamic>>('/backtest/${widget.runId}/status');
      if (mounted) {
        setState(() {
          _run = BacktestRun.fromJson(response.data ?? {});
          _loading = false;
          _error = null;
        });
        if (_run?.status == 'done' || _run?.status == 'failed' || _run?.status == 'cancelled') {
          _timer?.cancel();
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _cancel() async {
    try {
      await ApiClient.instance.delete<dynamic>('/backtest/${widget.runId}/cancel');
      _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cancel failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
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
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final run = _run!;
    final isDone = run.status == 'done';
    final isFailed = run.status == 'failed' || run.status == 'cancelled';
    final isRunning = run.status == 'running' || run.status == 'pending';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    if (isRunning)
                      Text('${_elapsed}s', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                  ]),
                  const SizedBox(height: 16),
                  _InfoRow('Run ID', '#${run.runId}'),
                  if (run.eaId != null) _InfoRow('EA ID', '#${run.eaId}'),
                  _InfoRow('Symbol', run.parameters['symbol']?.toString() ?? '-'),
                  _InfoRow('Period', run.parameters['period']?.toString() ?? '-'),
                  _InfoRow('From', run.parameters['from_date']?.toString() ?? '-'),
                  _InfoRow('To', run.parameters['to_date']?.toString() ?? '-'),
                  if (run.startedAt != null)
                    _InfoRow('Started', run.startedAt!.length > 19 ? run.startedAt!.substring(0, 19) : run.startedAt!),
                  if (run.finishedAt != null)
                    _InfoRow('Finished', run.finishedAt!.length > 19 ? run.finishedAt!.substring(0, 19) : run.finishedAt!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (isDone)
            ElevatedButton.icon(
              onPressed: () => context.push('/results?runId=${run.runId}'),
              icon: const Icon(Icons.bar_chart),
              label: const Text('View Results', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          if (isRunning)
            OutlinedButton.icon(
              onPressed: _cancel,
              icon: const Icon(Icons.stop, color: Color(0xFFEF4444)),
              label: const Text('Cancel', style: TextStyle(color: Color(0xFFEF4444))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          if (isFailed)
            OutlinedButton.icon(
              onPressed: () => context.go('/backtest/setup'),
              icon: const Icon(Icons.refresh),
              label: const Text('Run Again'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(
        width: 80,
        child: Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
      ),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );
}
