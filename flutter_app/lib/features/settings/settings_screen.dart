import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/storage_service.dart';
import '../../core/theme_provider.dart';
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
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadUrl();
    _loadPackageInfo();
  }

  Future<void> _loadUrl() async {
    final url = await StorageService.instance.getServerUrl();
    if (mounted) _urlCtrl.text = url;
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _packageInfo = info);
    } catch (_) {
      // Package info unavailable (e.g., in tests)
    }
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Server URL saved')));
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _healthResult = null;
      _healthError = null;
    });
    final url = _urlCtrl.text.trim();
    try {
      await StorageService.instance.saveServerUrl(url);
      final response =
          await ApiClient.instance.get<Map<String, dynamic>>('/health');
      if (mounted) {
        setState(() {
          _healthResult = response.data;
          _testingConnection = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _healthError = ApiClient.extractError(e);
          _testingConnection = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _healthError = ApiClient.extractError(e);
          _testingConnection = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Server section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SERVER',
                      style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant, letterSpacing: 1.2)),
                  const SizedBox(height: 14),
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
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.wifi_tethering_outlined),
                        label: const Text('Test'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saveUrl,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                    ),
                  ]),
                  if (_healthResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withAlpha(80)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.check_circle,
                                color: AppColors.success, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Connected — Status: ${_healthResult!['status'] ?? 'ok'}',
                              style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          _HealthRow('Terminal',
                              _healthResult!['terminal_ok'] as bool? ?? false),
                          _HealthRow('MetaEditor',
                              _healthResult!['metaeditor_ok'] as bool? ?? false),
                          _HealthRow('MQL5 Root',
                              _healthResult!['mql5_ok'] as bool? ?? false),
                          const SizedBox(height: 4),
                          Text(
                            'CPU: ${_healthResult!['cpu_percent']}%  '
                            'RAM: ${_healthResult!['memory_mb']} MB',
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_healthError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withAlpha(60),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.error.withAlpha(80)),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_outline, color: cs.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_healthError!,
                                style: tt.bodySmall
                                    ?.copyWith(color: cs.onErrorContainer))),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Theme section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('APPEARANCE',
                      style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant, letterSpacing: 1.2)),
                  const SizedBox(height: 14),
                  Text('Theme',
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode, size: 18),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto, size: 18),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode, size: 18),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {ref.watch(themeModeProvider)},
                    onSelectionChanged: (s) =>
                        ref.read(themeModeProvider.notifier).set(s.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // About section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ABOUT',
                      style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant, letterSpacing: 1.2)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.candlestick_chart,
                            color: cs.onPrimaryContainer, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MT5 EA Platform',
                              style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold)),
                          Text(
                            _packageInfo != null
                                ? 'Version ${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                                : 'Version 1.0.0',
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: cs.outlineVariant),
                  const SizedBox(height: 8),
                  Text(
                    'MetaTrader 5 Expert Advisor Automation Platform\n'
                    'REST API · WebSocket · MCP Server · Flutter Mobile',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: Icon(Icons.logout, color: cs.error),
            label: Text('Logout', style: TextStyle(color: cs.error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.error),
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
          Icon(ok ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 14,
              color: ok
                  ? AppColors.success
                  : Theme.of(context).colorScheme.error),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                color: ok
                    ? AppColors.success
                    : Theme.of(context).colorScheme.error,
                fontSize: 12),
          ),
        ]),
      );
}
