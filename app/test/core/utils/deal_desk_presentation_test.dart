import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/utils/deal_desk_presentation.dart';
import 'package:tradehub_demo/l10n/generated/app_localizations.dart';

void main() {
  group('DealDeskPresentation', () {
    test('accepted negotiation without an order remains order pending', () {
      final negotiation = <String, dynamic>{
        'status': 'accepted',
        'orderId': null,
      };

      expect(
        DealDeskPresentation.orderStatusLabel(negotiation),
        'Accepted · Order Pending',
      );
    });

    test('accepted negotiation with an order is shown as order created', () {
      final negotiation = <String, dynamic>{
        'status': 'accepted',
        'orderId': 'order-123',
      };

      expect(
        DealDeskPresentation.orderStatusLabel(negotiation),
        'Order Created',
      );
    });

    test('converted negotiation is shown as order created', () {
      final negotiation = <String, dynamic>{
        'status': 'converted',
        'orderId': null,
      };

      expect(
        DealDeskPresentation.orderStatusLabel(negotiation),
        'Order Created',
      );
    });

    test('a linked order takes precedence over a stale status', () {
      final negotiation = <String, dynamic>{
        'status': 'pending',
        'orderId': 'order-789',
      };

      expect(
        DealDeskPresentation.orderStatusLabel(negotiation),
        'Order Created',
      );
    });

    test('populated order reference counts only when it has an id', () {
      expect(
        DealDeskPresentation.hasLinkedOrder(<String, dynamic>{
          'orderId': <String, dynamic>{'_id': 'order-456'},
        }),
        isTrue,
      );
      expect(
        DealDeskPresentation.hasLinkedOrder(<String, dynamic>{
          'orderId': <String, dynamic>{'orderNumber': 'TH-456'},
        }),
        isFalse,
      );
    });

    test('labels follow the requested language', () {
      final hi = lookupAppLocalizations(const Locale('hi'));
      final en = lookupAppLocalizations(const Locale('en'));
      final pendingOrder = <String, dynamic>{'status': 'accepted'};
      final createdOrder = <String, dynamic>{'status': 'converted'};

      expect(
        DealDeskPresentation.orderStatus(pendingOrder),
        DealOrderStatus.acceptedOrderPending,
      );
      expect(
        DealDeskPresentation.orderStatusLabel(pendingOrder, l10n: en),
        'Accepted · Order Pending',
      );
      expect(
        DealDeskPresentation.orderStatusLabel(pendingOrder, l10n: hi),
        'स्वीकार · ऑर्डर लंबित',
      );
      expect(
        DealDeskPresentation.orderStatusLabel(createdOrder, l10n: hi),
        'ऑर्डर बन गया',
      );
      expect(
        DealDeskPresentation.orderStatusLabel(<String, dynamic>{
          'status': 'pending',
        }, l10n: hi),
        isNull,
      );
    });
  });
}
