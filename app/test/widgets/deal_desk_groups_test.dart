import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demomart_demo/l10n/l10n.dart';
import 'package:demomart_demo/widgets/deal_desk_groups.dart';

Map<String, dynamic> _deal(
  String id,
  num total, {
  Map<String, dynamic>? group,
}) => {'id': id, 'currentTotalPrice': total, 'requestGroup': group};

Future<List<Widget>> _entries(
  WidgetTester tester,
  List<Map<String, dynamic>> deals, {
  Locale locale = const Locale('en'),
}) async {
  late List<Widget> entries;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          entries = dealDeskEntries(
            context,
            deals,
            (deal) => Text('card ${deal['id']}', key: ValueKey(deal['id'])),
          );
          return Column(children: entries);
        },
      ),
    ),
  );
  return entries;
}

void main() {
  const group = {'id': 'g1', 'number': 'REQ-2026-00120012'};

  testWidgets('products sent together get one requirement header', (
    tester,
  ) async {
    final entries = await _entries(tester, [
      _deal('a', 75000, group: group),
      _deal('b', 21600, group: group),
      _deal('c', 18000, group: group),
      _deal('d', 14800),
    ]);
    // 1 header + 4 cards, header first.
    expect(entries.length, 5);
    expect(entries.first.key, const ValueKey('requirement-group-g1'));
    expect(
      find.text('Requirement REQ-2026-00120012 · 3 products · ₹1,14,600'),
      findsOneWidget,
    );
    expect(find.text('card d'), findsOneWidget);
  });

  testWidgets('single requirements have no header; Hindi header text', (
    tester,
  ) async {
    expect((await _entries(tester, [_deal('x', 100)])).length, 1);
    await _entries(tester, [
      _deal('a', 500, group: group),
      _deal('b', 500, group: group),
    ], locale: const Locale('hi'));
    expect(
      find.text('रिक्वायरमेंट REQ-2026-00120012 · 2 प्रोडक्ट · ₹1,000'),
      findsOneWidget,
    );
  });
}
