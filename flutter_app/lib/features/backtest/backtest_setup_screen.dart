import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/storage_service.dart';
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
  ConsumerState<BacktestSetupScreen> createState() =>
      _BacktestSetupScreenState();
}

class _BacktestSetupScreenState extends ConsumerState<BacktestSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  EAModel? _selectedEA;
  int? _lastEaId;
  final _symbolCtrl = TextEditingController(text: 'EURUSD');
  String _period = 'H1';
  DateTime _fromDate = DateTime(2024, 1, 1);
  DateTime _toDate = DateTime(2024, 12, 31);
  int _model = 1;
  final _depositCtrl = TextEditingController(text: '10000');
  final _currencyCtrl = TextEditingController(text: 'USD');
  final _leverageCtrl = TextEditingController(text: '100');
  bool _isRunning = false;
  bool _paramsLoaded = false;
  bool _eaAutoSelectAttempted = false;

  static const _periods = ['M1', 'M5', 'M15', 'M30', 'H1', 'H4', 'D1', 'W1', 'MN1'];
  static const _models = [
    MapEntry(0, 'Every tick'),
    MapEntry(1, '1 minute OHLC'),
    MapEntry(2, 'Open price only'),
  ];

  final _dateFmt = DateFormat('yyyy.MM.dd');

  @override
  void initState() {
    super.initState();
    _loadLastParams();
  }

  Future<void> _loadLastParams() async {
    final params = await StorageService.instance.getLastBacktestParams();
    if (mounted) {
      setState(() {
        _lastEaId = params['ea_id'] as int?;
        _symbolCtrl.text = params['symbol'] as String;
        _period = params['period'] as String;
        _fromDate = DateTime.tryParse(
                (params['from_date'] as String).replaceAll('.', '-')) ??
            DateTime(2024, 1, 1);
        _toDate = DateTime.tryParse(
                (params['to_date'] as String).replaceAll('.', '-')) ??
            DateTime(2024, 12, 31);
        _depositCtrl.text = (params['deposit'] as double).toStringAsFixed(0);
        _currencyCtrl.text = params['currency'] as String;
        _leverageCtrl.text = (params['leverage'] as int).toString();
        _model = params['model'] as int;
        _paramsLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _depositCtrl.dispose();
    _currencyCtrl.dispose();
    _leverageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? _fromDate : _toDate;
    final first = DateTime(2000);
    final last = DateTime(2030, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  Future<void> _run() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEA == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an EA')));
      return;
    }
    setState(() => _isRunning = true);

    final fromStr = _dateFmt.format(_fromDate);
    final toStr = _dateFmt.format(_toDate);
    final deposit = double.tryParse(_depositCtrl.text) ?? 10000.0;
    final leverage = int.tryParse(_leverageCtrl.text) ?? 100;

    try {
      // Persist params for next time
      await StorageService.instance.saveLastBacktestParams(
        eaId: _selectedEA!.id,
        symbol: _symbolCtrl.text.trim(),
        period: _period,
        fromDate: fromStr,
        toDate: toStr,
        deposit: deposit,
        currency: _currencyCtrl.text.trim(),
        leverage: leverage,
        model: _model,
      );

      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/backtest/run',
        data: {
          'ea_id': _selectedEA!.id,
          'ea_name': _selectedEA!.name,
          'symbol': _symbolCtrl.text.trim(),
          'period': _period,
          'from_date': fromStr,
          'to_date': toStr,
          'model': _model,
          'deposit': deposit,
          'currency': _currencyCtrl.text.trim(),
          'leverage': leverage,
        },
      );
      final runId = response.data?['run_id'] as int?;
      if (runId != null && mounted) {
        context.push('/backtest/monitor/$runId');
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = ApiClient.extractError(e);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $msg'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ));
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eaAsync = ref.watch(_eaDropdownProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Auto-select EA once list loads and we have a last ea id
    if (_paramsLoaded && !_eaAutoSelectAttempted && _selectedEA == null && _lastEaId != null) {
      eaAsync.whenData((eas) {
        _eaAutoSelectAttempted = true;
        final match = eas.cast<EAModel?>().firstWhere(
          (e) => e?.id == _lastEaId,
          orElse: () => null,
        );
        if (match != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedEA = match);
          });
        }
      });
    }

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
                title: 'EXPERT ADVISOR',
                child: eaAsync.when(
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )),
                  error: (e, _) => Text(
                      'Failed to load EAs: ${ApiClient.extractError(e)}',
                      style: TextStyle(color: cs.error)),
                  data: (eas) => DropdownButtonFormField<EAModel>(
                    value: _selectedEA,
                    dropdownColor: cs.surfaceContainerHigh,
                    decoration: const InputDecoration(
                        labelText: 'Select EA',
                        prefixIcon: Icon(Icons.code_outlined)),
                    hint: const Text('Choose an EA'),
                    items: eas
                        .map((ea) => DropdownMenuItem(
                              value: ea,
                              child: Text(ea.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedEA = v),
                    validator: (v) => v == null ? 'Select an EA' : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'MARKET',
                child: Column(children: [
                  TextFormField(
                    controller: _symbolCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Symbol',
                      prefixIcon: Icon(Icons.currency_exchange_outlined),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _period,
                    dropdownColor: cs.surfaceContainerHigh,
                    decoration: const InputDecoration(
                      labelText: 'Timeframe',
                      prefixIcon: Icon(Icons.access_time_outlined),
                    ),
                    items: _periods
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) => setState(() => _period = v!),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'DATE RANGE',
                child: Row(children: [
                  Expanded(
                    child: _DateField(
                      label: 'From',
                      date: _fromDate,
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'To',
                      date: _toDate,
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'TESTING MODE',
                child: DropdownButtonFormField<int>(
                  value: _model,
                  dropdownColor: cs.surfaceContainerHigh,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    prefixIcon: Icon(Icons.science_outlined),
                  ),
                  items: _models
                      .map((m) => DropdownMenuItem(
                          value: m.key, child: Text(m.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _model = v!),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'ACCOUNT',
                child: Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _depositCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Deposit',
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _currencyCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Currency'),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _leverageCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Leverage', prefixText: '1:'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isRunning ? null : _run,
                  icon: _isRunning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white))
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    _isRunning ? 'Starting...' : 'Run Backtest',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Text(
                'Last params auto-filled from previous run',
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateField(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          suffixIcon: Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
        ),
        child: Text(
          DateFormat('yyyy.MM.dd').format(date),
          style: TextStyle(color: cs.onSurface, fontSize: 14),
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
