import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_provider.dart';

class AppScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      drawer: _AppDrawer(currentTitle: title),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  final String currentTitle;

  const _AppDrawer({required this.currentTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            color: const Color(0xFF111827),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.candlestick_chart,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'MT5 EA Platform',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Automation Dashboard',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  route: '/dashboard',
                  currentTitle: currentTitle,
                ),
                _DrawerItem(
                  icon: Icons.code_outlined,
                  label: 'EA Manager',
                  route: '/ea',
                  currentTitle: currentTitle,
                ),
                _DrawerItem(
                  icon: Icons.play_circle_outlined,
                  label: 'Backtest',
                  route: '/backtest/setup',
                  currentTitle: currentTitle,
                ),
                _DrawerItem(
                  icon: Icons.bar_chart_outlined,
                  label: 'Results',
                  route: '/results',
                  currentTitle: currentTitle,
                ),
                _DrawerItem(
                  icon: Icons.history_outlined,
                  label: 'History',
                  route: '/history',
                  currentTitle: currentTitle,
                ),
                _DrawerItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Trade Ledger',
                  route: '/ledger',
                  currentTitle: currentTitle,
                ),
                _DrawerItem(
                  icon: Icons.list_alt_outlined,
                  label: 'Usage Log',
                  route: '/usage',
                  currentTitle: currentTitle,
                ),
                const Divider(
                  color: Color(0xFF374151),
                  indent: 16,
                  endIndent: 16,
                ),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  route: '/settings',
                  currentTitle: currentTitle,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.logout,
                    color: Color(0xFFEF4444),
                    size: 22,
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 15,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentTitle;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentTitle,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentTitle == label;

    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF9CA3AF),
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? const Color(0xFF3B82F6) : Colors.white,
          fontSize: 15,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      tileColor: isActive ? const Color(0xFF3B82F6).withAlpha(26) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: () {
        Navigator.of(context).pop();
        context.go(route);
      },
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 2,
      ),
    );
  }
}
