import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../shared/models/ea_model.dart';
import '../../shared/widgets/app_scaffold.dart';

final _eaDropdownProvider = FutureProvider<List<EAModel>>((ref) async {
  final response = await ApiClient.instance.get<List<dynamic>>('/ea/list');
  return (response.data ?? [])
      .map((e) => EAModel.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

class BacktestSetupScreen extends ConsumerStatefulWidget {
  const BacktestSetupScreen({super.key});

  @override
  ConsumerState<BacktestSetupScreen> createState() => _BacktestSetupScreenState();
}

class _BacktestSetupScreenState extends ConsumerState<BacktestSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  EAModel? _selectedEA;
  final _symbolCtrl = TextEditingController(text: 'EURUSD');
  String _period = 'H1';
  final _fromCtrl = TextEditingController(text: '2024.01.01');
  final _toCtrl = TextEditingController(text: '2024.12.31');
  int _model = 1;
  final _depositCtrl = TextEditingController(text: '10000');
  final _currencyCtrl = TextEditingController(text: 'USD');
  final _leverageCtrl = TextEditingController(text: '100');
  bool _isRunning = false;

  static const _periods = ['M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1', 'MN1'];
  static const _models = [
    MapEntry(0, 'Every tick'),
    MapEntry(1, '1 minute OHLC'),
    MapEntry(2, 'Open price only'),
  ];

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _depositCtrl.dispose();
    _currencyCtrl.dispose();
    _leverageCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEA == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an EA')));
      return;
    }
    setState(() => _isRunning = true);
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/backtest/run',
        data: {
          'ea_id': _selectedEA!.id,
          'ea_name': _selectedEA!.name,
          'symbol': _symbolCtrl.text.trim(),
          'period': _period,
          'from_date': _fromCtrl.text.trim(),
          'to_date': _toCtrl.text.trim(),
          'model': _model,
          'deposit': double.tryParse(_depositCtrl.text) ?? 10000.0,
          'currency': _currencyCtrl.text.trim(),
          'leverage': int.tryParse(_leverageCtrl.text) ?? 100,
        },
      );
      final runId = response.data?['run_id'] as int?;
      if (runId != null && mounted) {
        context.push('/backtest/monitor/$runId');
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['detail']?.toString() ?? e.message ?? 'Failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $msg'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eaAsync = ref.watch(_eaDropdownProvider);

    return AppScaffold(
      title: 'Run Backtest',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                title: 'Expert Advisor',
                child: eaAsync.when(
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (e, _) => Text('Failed to load EAs: $e',
                      style: const TextStyle(color: Color(0xFFEF4444))),
                  data: (eas) => DropdownButtonFormField<EAModel>(
                    value: _selectedEA,
                    dropdownColor: const Color(0xFF1F2937),
                    decoration: const InputDecoration(labelText: 'Select EA'),
                    hint: const Text('Choose an EA'),
                    items: eas.map((ea) => DropdownMenuItem(
                      value: ea,
                      child: Text(ea.name),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedEA = v),
                    validator: (v) => v == null ? 'Select an EA' : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Market',
                child: Column(children: [
                  TextFormField(
                    controller: _symbolCtrl,
                    decoration: const InputDecoration(labelText: 'Symbol'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _period,
                    dropdownColor: const Color(0xFF1F2937),
                    decoration: const InputDecoration(labelText: 'Timeframe'),
                    items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => setState(() => _period = v!),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Date Range',
                child: Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fromCtrl,
                      decoration: const InputDecoration(labelText: 'From'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _toCtrl,
                      decoration: const InputDecoration(labelText: 'To'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Testing Mode',
                child: DropdownButtonFormField<int>(
                  value: _model,
                  dropdownColor: const Color(0xFF1F2937),
                  decoration: const InputDecoration(labelText: 'Model'),
                  items: _models.map((m) => DropdownMenuItem(
                    value: m.key,
                    child: Text(m.value),
                  )).toList(),
                  onChanged: (v) => setState(() => _model = v!),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Account',
                child: Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _depositCtrl,
                      decoration: const InputDecoration(labelText: 'Deposit'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _currencyCtrl,
                      decoration: const InputDecoration(labelText: 'Currency'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _leverageCtrl,
                      decoration: const InputDecoration(labelText: 'Leverage'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isRunning ? null : _run,
                  icon: _isRunning
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow),
                  label: Text(_isRunning ? 'Starting...' : 'Run Backtest',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}
