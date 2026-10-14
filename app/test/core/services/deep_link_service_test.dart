import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:demomart_demo/core/services/deep_link_service.dart';
import 'package:demomart_demo/core/utils/product_share.dart';
import 'package:demomart_demo/l10n/l10n.dart';

void main() {
  group('shared product links', () {
    String? route(String url) => DeepLinkService.routeFor(Uri.parse(url));

    test('a product link opens that product', () {
      expect(
        route(
          'https://demo.demomart.example/products/3-hp-4-stage-tp-v-6-golden',
        ),
        '/product/3-hp-4-stage-tp-v-6-golden',
      );
      expect(
        route('https://www.demo.demomart.example/products/pipe-2-inch/?x=1'),
        '/product/pipe-2-inch',
      );
    });

    test('other links are ignored', () {
      expect(route('https://demo.demomart.example/'), isNull);
      expect(route('https://demo.demomart.example/products'), isNull);
      expect(route('https://demo.demomart.example/brand/sample'), isNull);
      expect(route('https://example.com/products/pump'), isNull);
      expect(
        route('https://demo.demomart.example/products/a/b'),
        isNull,
      );
    });
  });

  group('share text', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test("a wholesaler shares the retail price, never their own", () {
      final text = productShareMessage(l10n, {
        'slug': '3-hp-4-stage-tp-v-6-golden',
        'price': 12000, // the wholesaler's price in their response
        'retailPrice': 13600,
      }, name: '3 HP 4 STAGE T.P. V-6 Golden');
      expect(text, contains('₹13600'));
      expect(text, isNot(contains('12000')));
      expect(
        text,
        endsWith(
          'https://demo.demomart.example/products/3-hp-4-stage-tp-v-6-golden',
        ),
      );
    });

    test('customers share their (retail) price', () {
      final text = productShareMessage(l10n, {
        'slug': 'pump',
        'price': 13600,
      }, name: 'Pump');
      expect(text, contains('₹13600'));
    });

    test('no price for a Coming Soon product with a hidden price', () {
      final text = productShareMessage(l10n, {
        'slug': 'pump',
        'retailPrice': 0,
        'comingSoon': true,
        'priceHidden': true,
      }, name: 'Pump');
      expect(text, isNot(contains('₹')));
      expect(text, contains('/products/pump'));
    });
  });
}
