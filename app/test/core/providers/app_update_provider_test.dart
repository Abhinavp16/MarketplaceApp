import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/models/app_update_config.dart';
import 'package:tradehub_demo/core/navigation/app_navigator_key.dart';
import 'package:tradehub_demo/core/providers/app_update_provider.dart';
import 'package:tradehub_demo/core/services/app_update_service.dart';
import 'package:tradehub_demo/l10n/l10n.dart';

class _FakeUpdateGateway implements AppUpdateGateway {
  final List<AppUpdateCheckResult> results = [];

  @override
  Future<AppUpdateCheckResult> checkForMandatoryUpdate() async {
    return results.removeAt(0);
  }

  @override
  Future<bool> openStore(Uri storeUri) async => true;
}

void main() {
  testWidgets(
    'active gate survives navigation and confirmed disable releases it',
    (tester) async {
      final gateway = _FakeUpdateGateway();
      final requirement = AppUpdateRequirement(
        currentVersion: '1.0.6',
        latestVersion: '1.0.7',
        storeUri: Uri.parse('https://example.com/store'),
        title: 'Update Required',
        message: 'Please update to continue.',
      );
      gateway.results.add(AppUpdateCheckResult.success(requirement));
      final controller = AppUpdateController(gateway);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorKey: appNavigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      );

      await controller.checkAndShow(
        appNavigatorKey.currentContext!,
        isInitialCheck: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('Update Required'), findsOneWidget);

      appNavigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Update Required'), findsOneWidget);

      gateway.results.add(const AppUpdateCheckResult.success(null));
      await controller.checkAndShow(appNavigatorKey.currentContext!);
      await tester.pumpAndSettle();
      expect(find.text('Update Required'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    },
  );
}
