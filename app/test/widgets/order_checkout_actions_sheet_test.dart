import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/services/api_client.dart';
import 'package:tradehub_demo/l10n/l10n.dart';
import 'package:tradehub_demo/widgets/order_checkout_actions_sheet.dart';

void main() {
  group('checkout response routing', () {
    test('uses in-app approval for the complete new contract', () {
      final response = {
        'success': true,
        'data': {
          'nextAction': 'await_acceptance',
          'requiresWhatsapp': false,
          'order': {'id': 'order-1', 'orderNumber': 'TH-101'},
        },
      };

      expect(OrderCheckoutActionsSheet.usesInAppApprovalFlow(response), isTrue);
    });

    test('retains legacy flow when nextAction is absent', () {
      final response = {
        'success': true,
        'data': {'requiresWhatsapp': false, 'orderId': 'order-1'},
      };

      expect(
        OrderCheckoutActionsSheet.usesInAppApprovalFlow(response),
        isFalse,
      );
    });

    test('retains legacy flow when WhatsApp is still required', () {
      final response = {
        'success': true,
        'data': {'nextAction': 'await_acceptance', 'requiresWhatsapp': true},
      };

      expect(
        OrderCheckoutActionsSheet.usesInAppApprovalFlow(response),
        isFalse,
      );
    });
  });

  group('awaiting approval dialog', () {
    const response = {
      'success': true,
      'data': {
        'nextAction': 'await_acceptance',
        'requiresWhatsapp': false,
        'order': {'id': 'order-1', 'orderNumber': 'TH-101'},
      },
    };

    Future<void> showApprovalDialog(WidgetTester tester, Locale locale) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    OrderCheckoutActionsSheet.handleSuccessfulCheckout(
                      context: context,
                      apiClient: ApiClient(),
                      responseData: response,
                    ),
                child: const Text('Checkout'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the approval message in English', (tester) async {
      await showApprovalDialog(tester, const Locale('en'));

      expect(find.text('Order Submitted'), findsOneWidget);
      expect(find.text('Awaiting Approval'), findsOneWidget);
      expect(find.text('Order TH-101'), findsOneWidget);
      expect(
        find.textContaining('team reviews your order'),
        findsOneWidget,
      );
      expect(find.text('View Order'), findsOneWidget);
      expect(find.text('Continue Shopping'), findsOneWidget);
    });

    testWidgets('shows the approval message in Hindi', (tester) async {
      await showApprovalDialog(tester, const Locale('hi'));

      expect(find.text('ऑर्डर भेज दिया गया'), findsOneWidget);
      expect(find.text('मंज़ूरी का इंतज़ार'), findsOneWidget);
      // Order numbers stay as written.
      expect(find.text('ऑर्डर TH-101'), findsOneWidget);
      expect(find.text('ऑर्डर देखें'), findsOneWidget);
      expect(find.text('खरीदारी जारी रखें'), findsOneWidget);
      expect(find.textContaining('ट्रेडहब डेमो'), findsOneWidget);
    });
  });
}
