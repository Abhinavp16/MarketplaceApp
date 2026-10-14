import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demomart_demo/l10n/l10n.dart';
import 'package:demomart_demo/widgets/coming_soon_badge.dart';

Future<void> _pump(WidgetTester tester, Locale locale) => tester.pumpWidget(
  MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Column(
          children: [
            const ComingSoonBadge(uppercase: false),
            Text(context.l10n.comingSoonPrice),
            Text(context.l10n.comingSoonNotifyMe),
            Text(context.l10n.comingSoonExpected('15 Oct')),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('coming soon texts in English and Hindi', (tester) async {
    await _pump(tester, const Locale('en'));
    expect(find.byKey(const ValueKey('coming-soon-badge')), findsOneWidget);
    expect(find.text('Coming Soon'), findsOneWidget);
    expect(find.text('Price coming soon'), findsOneWidget);
    expect(find.text('Notify me when available'), findsOneWidget);
    expect(find.text('Expected 15 Oct'), findsOneWidget);

    await _pump(tester, const Locale('hi'));
    expect(find.text('जल्द आ रहा है'), findsOneWidget);
    expect(find.text('कीमत जल्द'), findsOneWidget);
    expect(find.text('उपलब्ध होने पर सूचित करें'), findsOneWidget);
    expect(find.text('अनुमानित 15 Oct'), findsOneWidget);
  });
}
