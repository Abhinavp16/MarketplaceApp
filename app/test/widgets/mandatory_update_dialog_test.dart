import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/models/app_update_config.dart';
import 'package:tradehub_demo/l10n/l10n.dart';
import 'package:tradehub_demo/widgets/mandatory_update_dialog.dart';

void main() {
  testWidgets('dialog shows versions and cannot be dismissed with back', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => MandatoryUpdateDialog(
                  requirement: AppUpdateRequirement(
                    currentVersion: '1.0.6',
                    latestVersion: '1.2.0',
                    storeUri: Uri.parse('https://example.com/store'),
                    title: 'Update Required',
                    message: 'Please update to continue.',
                  ),
                  onUpdate: () async => true,
                ),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('Update Required'), findsOneWidget);
    expect(find.text('1.0.6'), findsOneWidget);
    expect(find.text('1.2.0'), findsOneWidget);
    expect(find.text('Update Now'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Update Required'), findsOneWidget);
  });

  testWidgets('dialog reports a store launch failure', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MandatoryUpdateDialog(
          requirement: AppUpdateRequirement(
            currentVersion: '1.0.6',
            latestVersion: '1.2.0',
            storeUri: Uri.parse('https://example.com/store'),
            title: 'Update Required',
            message: 'Please update to continue.',
          ),
          onUpdate: () async => false,
        ),
      ),
    );

    await tester.tap(find.text('Update Now'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unable to open the app store'), findsOneWidget);
    expect(find.text('Update Now'), findsOneWidget);
  });
}
