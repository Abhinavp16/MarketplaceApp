import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demomart_demo/l10n/l10n.dart';
import 'package:demomart_demo/widgets/cart_requirement.dart';

DioException _rejected(Map<String, dynamic> body) {
  final options = RequestOptions(path: '/negotiations/from-cart');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: 400, data: body),
  );
}

Future<String> _errorText(
  WidgetTester tester,
  Object error, {
  Locale locale = const Locale('en'),
}) async {
  late String text;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          text = cartRequirementErrorText(context, error);
          return const SizedBox();
        },
      ),
    ),
  );
  return text;
}

void main() {
  final blocked = _rejected({
    'success': false,
    'message': "Some cart items can't be sent as a requirement: Panel, Pump",
    'error': {
      'code': 'NEGOTIATION_DISABLED',
      'details': {
        'items': [
          {'productId': 'a', 'name': 'Panel', 'code': 'NEGOTIATION_DISABLED'},
          {'productId': 'b', 'name': 'Pump', 'code': 'NEGOTIATION_DISABLED'},
        ],
      },
    },
  });

  testWidgets('names the cart items that blocked the requirement', (
    tester,
  ) async {
    expect(
      await _errorText(tester, blocked),
      'Remove these items to send the requirement: Panel, Pump',
    );
    expect(
      await _errorText(tester, blocked, locale: const Locale('hi')),
      'रिक्वायरमेंट भेजने के लिए ये आइटम हटाएं: Panel, Pump',
    );
  });

  testWidgets('falls back to the usual error text', (tester) async {
    final empty = _rejected({
      'success': false,
      'message': 'Cart is empty',
      'error': {'code': 'CART_EMPTY'},
    });
    expect(await _errorText(tester, empty), 'Your cart is empty.');
  });

  testWidgets('sent message counts products in both languages', (tester) async {
    late AppLocalizations en;
    late AppLocalizations hi;
    for (final locale in const [Locale('en'), Locale('hi')]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              if (locale.languageCode == 'en') {
                en = context.l10n;
              } else {
                hi = context.l10n;
              }
              return const SizedBox();
            },
          ),
        ),
      );
    }
    expect(
      en.cartRequirementSent(3),
      'Requirement sent for 3 products. DemoMart will reply in Deal Desk.',
    );
    expect(
      hi.cartRequirementSent(1),
      '1 प्रोडक्ट की रिक्वायरमेंट भेज दी गई। डेमोमार्ट डील डेस्क में जवाब देगा।',
    );
  });
}
