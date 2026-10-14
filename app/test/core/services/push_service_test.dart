import 'package:demomart_demo/core/services/firebase_push_service.dart';
import 'package:demomart_demo/core/services/notification_navigation_service.dart';
import 'package:demomart_demo/core/services/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('push without Firebase configuration', () {
    test('the default push service is the no-op one', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final push = container.read(pushServiceProvider);
      expect(push, isA<NoopPushService>());
      expect(push.currentToken, isNull);
    });

    test('the no-op service never throws', () async {
      const push = NoopPushService();
      await push.initialize();
      await push.initialize(requestPermission: true);
      await push.unregister();
    });

    test('bootstrap stays off when Firebase cannot initialise', () async {
      var attempts = 0;
      final ready = await FirebasePushService.bootstrap(
        enabled: true,
        initializer: () async {
          attempts++;
          throw StateError('no google-services.json');
        },
      );
      expect(ready, isFalse);
      expect(attempts, 1);
    });

    test('bootstrap does not touch Firebase when push is disabled', () async {
      var attempts = 0;
      final ready = await FirebasePushService.bootstrap(
        enabled: false,
        initializer: () async => attempts++,
      );
      expect(ready, isFalse);
      expect(attempts, 0);
    });

    test('bootstrap succeeds when initialisation works', () async {
      expect(
        await FirebasePushService.bootstrap(
          enabled: true,
          initializer: () async {},
        ),
        isTrue,
      );
    });

    test('overrides are empty unless Firebase is ready', () {
      expect(pushServiceOverrides(firebaseReady: false), isEmpty);
      expect(pushServiceOverrides(firebaseReady: true), hasLength(1));
    });

    test('the notification service reports no token and unregisters safely',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(notificationServiceProvider);
      expect(service.currentToken, isNull);
      await service.unregisterPush();
    });
  });

  group('push payload routing', () {
    final nav = NotificationNavigationService.instance;

    test('product_launched opens the product', () {
      final destination = nav.destinationFor({
        'type': 'product_launched',
        'productId': '65f0c0ffee',
        'slug': 'x',
      });
      expect(destination?.route, '/product/65f0c0ffee');
      expect(destination?.requiresAuthentication, isFalse);
    });

    test('order and negotiation payloads route to their screens', () {
      expect(
        nav.destinationFor({'type': 'order_update', 'orderId': 'o1'})?.route,
        '/tracking/o1',
      );
      expect(
        nav
            .destinationFor({
              'type': 'negotiation_countered',
              'negotiationId': 'n1',
            })
            ?.route,
        '/negotiation-detail/n1',
      );
    });
  });
}
