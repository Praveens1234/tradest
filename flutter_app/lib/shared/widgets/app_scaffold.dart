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
      drawer: _AppDrawer(),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return Drawer(
      backgroundColor: cs.surfaceContainer,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primaryContainer,
                  cs.surfaceContainer,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withAlpha(80),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.candlestick_chart,
                    color: cs.onPrimary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'MT5 EA Platform',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Automation Dashboard',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onPrimaryContainer.withAlpha(180),
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
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  route: '/dashboard',
                  currentRoute: currentRoute,
                ),
                _DrawerItem(
                  icon: Icons.code_outlined,
                  activeIcon: Icons.code,
                  label: 'EA Manager',
                  route: '/ea',
                  currentRoute: currentRoute,
                ),
                _DrawerItem(
                  icon: Icons.play_circle_outlined,
                  activeIcon: Icons.play_circle,
                  label: 'Backtest',
                  route: '/backtest/setup',
                  currentRoute: currentRoute,
                ),
                _DrawerItem(
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history,
                  label: 'History',
                  route: '/history',
                  currentRoute: currentRoute,
                ),
                _DrawerItem(
                  icon: Icons.folder_outlined,
                  activeIcon: Icons.folder,
                  label: 'Files',
                  route: '/files',
                  currentRoute: currentRoute,
                ),
                _DrawerItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  label: 'Results',
                  route: '/results',
                  currentRoute: currentRoute,
                ),
                _DrawerItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Trade Ledger',
                  route: '/ledger',
                  currentRoute: currentRoute,
                ),
                _DrawerItem(
                  icon: Icons.list_alt_outlined,
                  activeIcon: Icons.list_alt,
                  label: 'Usage Log',
                  route: '/usage',
                  currentRoute: currentRoute,
                ),
                _DrawerItem(
                  icon: Icons.terminal_outlined,
                  activeIcon: Icons.terminal,
                  label: 'Platform Logs',
                  route: '/logs',
                  currentRoute: currentRoute,
                ),
                Divider(
                  color: cs.outlineVariant,
                  indent: 16,
                  endIndent: 16,
                ),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Settings',
                  route: '/settings',
                  currentRoute: currentRoute,
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: cs.error, size: 22),
                  title: Text(
                    'Logout',
                    style: TextStyle(color: cs.error, fontSize: 15),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
  final IconData activeIcon;
  final String label;
  final String route;
  final String currentRoute;

  const _DrawerItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    required this.currentRoute,
  });

  bool get _isActive {
    if (route == '/dashboard') return currentRoute == '/dashboard' || currentRoute == '/';
    return currentRoute.startsWith(route);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = _isActive;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        leading: Icon(
          isActive ? activeIcon : icon,
          color: isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? cs.onPrimaryContainer : cs.onSurface,
            fontSize: 15,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        tileColor: isActive ? cs.primaryContainer : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {
          Navigator.of(context).pop();
          context.go(route);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    );
  }
}
