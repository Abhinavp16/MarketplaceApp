import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/models/app_update_config.dart';
import 'package:tradehub_demo/core/services/app_update_service.dart';

void main() {
  group('mandatory update decision', () {
    final config = AppUpdateConfig.fromJson({
      'enabled': true,
      'latestBuildNumber': 12,
      'latestVersion': '1.2.0',
      'storeUrl': 'https://example.com/store',
      'title': 'Update Required',
      'message': 'Please update to continue.',
    });

    test('requires an update below the minimum build', () {
      final result = AppUpdateService.evaluate(
        config: config,
        currentVersion: '1.0.6',
        currentBuildNumber: 9,
      );

      expect(result, isNotNull);
      expect(result!.latestVersion, '1.2.0');
    });

    test('allows a build at or above the minimum', () {
      final result = AppUpdateService.evaluate(
        config: config,
        currentVersion: '1.2.0',
        currentBuildNumber: 12,
      );

      expect(result, isNull);
    });

    test('disabled configuration is a no-op', () {
      final disabled = AppUpdateConfig.fromJson({'enabled': false});

      expect(
        AppUpdateService.evaluate(
          config: disabled,
          currentVersion: '1.0.0',
          currentBuildNumber: 1,
        ),
        isNull,
      );
    });

    test('rejects an insecure store URL', () {
      expect(
        () => AppUpdateConfig.fromJson({
          'enabled': true,
          'latestBuildNumber': 12,
          'latestVersion': '1.2.0',
          'storeUrl': 'http://example.com/store',
          'title': 'Update Required',
          'message': 'Please update to continue.',
        }),
        throwsFormatException,
      );
    });

    test('rejects a non-positive latest build number', () {
      expect(
        () => AppUpdateConfig.fromJson({
          'enabled': true,
          'latestBuildNumber': 0,
          'latestVersion': '1.2.0',
          'storeUrl': 'https://example.com/store',
          'title': 'Update Required',
          'message': 'Please update to continue.',
        }),
        throwsFormatException,
      );
    });
  });
}
