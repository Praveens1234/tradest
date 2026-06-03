import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../core/storage_service.dart';
import '../../features/auth/auth_provider.dart';
import '../../shared/widgets/app_scaffold.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  bool _testingConnection = false;
  Map<String, dynamic>? _healthResult;
  String? _healthError;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final url = await StorageService.instance.getServerUrl();
    if (mounted) _urlCtrl.text = url;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    await StorageService.instance.saveServerUrl(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server URL saved')));
    }
  }

  Future<void> _testConnection() async {
    setState(() { _testingConnection = true; _healthResult = null; _healthError = null; });
    final url = _urlCtrl.text.trim();
    try {
      await StorageService.instance.saveServerUrl(url);
      final response = await ApiClient.instance.get<Map<String, dynamic>>('/health');
      if (mounted) {
        setState(() {
          _healthResult = response.data;
          _testingConnection = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _healthError = e.response?.data?['detail']?.toString() ?? e.message ?? 'Connection failed';
          _testingConnection = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _healthError = e.toString(); _testingConnection = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SERVER', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://192.168.1.10:8000',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testingConnection ? null : _testConnection,
                        icon: _testingConnection
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.wifi_tethering),
                        label: const Text('Test Connection'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveUrl,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                    ),
                  ]),
                  if (_healthResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF052E16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF22C55E).withAlpha(102)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Status: ${_healthResult!['status'] ?? 'ok'}',
                              style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w600),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          _HealthRow('Terminal', _healthResult!['terminal_ok'] as bool? ?? false),
                          _HealthRow('MetaEditor', _healthResult!['metaeditor_ok'] as bool? ?? false),
                          _HealthRow('MQL5 Root', _healthResult!['mql5_ok'] as bool? ?? false),
                          const SizedBox(height: 4),
                          Text(
                            'CPU: ${_healthResult!['cpu_percent']}%  RAM: ${_healthResult!['memory_mb']} MB',
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_healthError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A0000),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF4444).withAlpha(102)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_healthError!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12))),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ABOUT', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('MT5 EA Platform'),
                    subtitle: Text('Version 1.0.0', style: TextStyle(color: Color(0xFF9CA3AF))),
                    leading: Icon(Icons.candlestick_chart, color: Color(0xFF3B82F6)),
                  ),
                  const Divider(),
                  const Text(
                    'MetaTrader 5 Expert Advisor Automation Platform\n'
                    'REST API · MCP Server · Flutter Mobile',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            label: const Text('Logout', style: TextStyle(color: Color(0xFFEF4444))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEF4444)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final bool ok;
  const _HealthRow(this.label, this.ok);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(ok ? Icons.check : Icons.close, size: 14, color: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444), fontSize: 12)),
    ]),
  );
}
