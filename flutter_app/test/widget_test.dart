import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt5_ea_platform/shared/widgets/status_badge.dart';
import 'package:mt5_ea_platform/shared/widgets/stat_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

void main() {
  group('StatusBadge', () {
    for (final status in ['done', 'running', 'failed', 'cancelled', 'pending']) {
      testWidgets('renders $status', (tester) async {
        await tester.pumpWidget(_wrap(StatusBadge(status: status)));
        expect(find.text(_cap(status)), findsOneWidget);
      });
    }
  });

  group('StatCard', () {
    testWidgets('renders label and value', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatCard(label: 'Net Profit', value: r'$1,234.56')),
      );
      expect(find.text('Net Profit'), findsOneWidget);
      expect(find.text(r'$1,234.56'), findsOneWidget);
    });

    testWidgets('renders optional subtitle', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatCard(
          label: 'Win Rate',
          value: '65%',
          subtitle: '32 of 49 trades',
        )),
      );
      expect(find.text('32 of 49 trades'), findsOneWidget);
    });
  });
}
