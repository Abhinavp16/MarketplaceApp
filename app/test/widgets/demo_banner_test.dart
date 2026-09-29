import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/widgets/demo_banner.dart';

void main() {
  testWidgets('demo banner wraps the app and shows the static text', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoInfoProvider.overrideWith((ref) async => null)],
        child: const MaterialApp(
          home: DemoBannerShell(child: Scaffold(body: Text('Home content'))),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Demonstration Environment — synthetic data'),
      findsOneWidget,
    );
    expect(find.text('Home content'), findsOneWidget);
  });

  testWidgets('demo banner appends the seeded date when info is reachable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoInfoProvider.overrideWith(
            (ref) async => DemoInfo(
              demoMode: true,
              seededAt: DateTime.utc(2026, 9, 1, 12),
            ),
          ),
        ],
        child: const MaterialApp(
          home: DemoBannerShell(child: Scaffold(body: SizedBox())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('seeded 2026-09-01'), findsOneWidget);
  });
}
