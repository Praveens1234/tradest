import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/ea/ea_list_screen.dart';
import '../features/ea/ea_detail_screen.dart';
import '../features/backtest/backtest_setup_screen.dart';
import '../features/backtest/backtest_monitor_screen.dart';
import '../features/backtest/results_screen.dart';
import '../features/history/history_screen.dart';
import '../features/trade_ledger/trade_ledger_screen.dart';
import '../features/usage/usage_log_screen.dart';
import '../features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (BuildContext context, GoRouterState state) {
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final isAuthenticated = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoginRoute) {
        return '/login';
      }
      if (isAuthenticated && isLoginRoute) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        redirect: (context, state) => '/dashboard',
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/ea',
        builder: (context, state) => const EAListScreen(),
      ),
      GoRoute(
        path: '/ea/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return EADetailScreen(eaId: id);
        },
      ),
      GoRoute(
        path: '/backtest/setup',
        builder: (context, state) => const BacktestSetupScreen(),
      ),
      GoRoute(
        path: '/backtest/monitor/:runId',
        builder: (context, state) {
          final runId = int.tryParse(state.pathParameters['runId'] ?? '') ?? 0;
          return BacktestMonitorScreen(runId: runId);
        },
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) {
          final runIdStr = state.uri.queryParameters['runId'];
          final runId = runIdStr != null ? int.tryParse(runIdStr) : null;
          return ResultsScreen(runId: runId);
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/ledger',
        builder: (context, state) {
          final runIdStr = state.uri.queryParameters['runId'];
          final runId = runIdStr != null ? int.tryParse(runIdStr) : null;
          return TradeLedgerScreen(runId: runId);
        },
      ),
      GoRoute(
        path: '/usage',
        builder: (context, state) => const UsageLogScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
