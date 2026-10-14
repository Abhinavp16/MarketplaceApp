import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:demomart_demo/core/services/notification_navigation_service.dart';
import 'package:demomart_demo/core/utils/coming_soon.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  test('coming soon and hidden price come from the server flags', () {
    expect(isComingSoonProduct({'comingSoon': true}), isTrue);
    expect(isComingSoonProduct({'comingSoon': false}), isFalse);
    expect(isComingSoonProduct(null), isFalse);
    expect(isPriceHidden({'comingSoon': true, 'priceHidden': true}), isTrue);
    expect(isPriceHidden({'comingSoon': true, 'priceHidden': false}), isFalse);
    // A live product never hides its price.
    expect(isPriceHidden({'comingSoon': false, 'priceHidden': true}), isFalse);
  });

  test('expected date text drops the year only for this year', () {
    final now = DateTime(2026, 10, 1);
    final product = {
      'comingSoon': true,
      'expectedDate': DateTime(2026, 10, 15, 12).toIso8601String(),
    };
    expect(expectedLaunchText(product, 'en', now: now), '15 Oct');
    expect(
      expectedLaunchText(
        {'expectedDate': DateTime(2027, 1, 5, 12).toIso8601String()},
        'en',
        now: now,
      ),
      '5 Jan 2027',
    );
    expect(expectedLaunchText(product, 'hi', now: now), startsWith('15 '));
    expect(expectedLaunchText({'expectedDate': null}, 'en'), isNull);
    expect(expectedLaunchText({'expectedDate': ''}, 'en'), isNull);
  });

  test('a launch notification opens the product', () {
    final destination = NotificationNavigationService.instance.destinationFor({
      'type': 'product_launched',
      'productId': 'p1',
    });
    expect(destination?.route, '/product/p1');
    expect(destination?.requiresAuthentication, isFalse);
  });
}
