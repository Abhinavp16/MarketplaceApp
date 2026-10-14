import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demomart_demo/widgets/ui/app_feedback.dart';

Future<void> _show(WidgetTester tester, {required bool withAction}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppSnack(
              context,
              'Pipe removed',
              actionLabel: withAction ? 'Undo' : null,
              onAction: withAction ? () {} : null,
              duration: const Duration(seconds: 5),
            ),
            child: const Text('remove'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('remove'));
  await tester.pumpAndSettle();
}

void main() {
  // Flutter keeps a snack bar with an action on screen until it's tapped
  // unless it is told not to persist; ours must still go away on time.
  testWidgets('a message with Undo goes away after its duration', (
    tester,
  ) async {
    await _show(tester, withAction: true);
    expect(find.text('Pipe removed'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Pipe removed'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Pipe removed'), findsNothing);
  });

  testWidgets('a plain message also goes away after its duration', (
    tester,
  ) async {
    await _show(tester, withAction: false);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Pipe removed'), findsNothing);
  });
}
