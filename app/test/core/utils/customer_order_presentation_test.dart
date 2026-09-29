import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/utils/customer_order_presentation.dart';
import 'package:tradehub_demo/l10n/generated/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final hi = lookupAppLocalizations(const Locale('hi'));

  group('CustomerOrderPresentation', () {
    test('pending acceptance takes precedence over fulfillment status', () {
      final order = <String, dynamic>{
        'acceptanceStatus': 'pending',
        'status': 'pending_payment',
      };

      expect(CustomerOrderPresentation.stage(order), 'awaiting_acceptance');
      expect(
        CustomerOrderPresentation.label(
          en,
          CustomerOrderPresentation.stage(order),
        ),
        'Submitted · Awaiting Approval',
      );
      expect(
        CustomerOrderPresentation.label(
          hi,
          CustomerOrderPresentation.stage(order),
        ),
        'भेजा गया · मंज़ूरी का इंतज़ार',
      );
      expect(CustomerOrderPresentation.timeline(order), [
        'awaiting_acceptance',
      ]);
    });

    test('accepted order starts the fulfillment timeline', () {
      final order = <String, dynamic>{
        'acceptanceStatus': 'accepted',
        'status': 'payment_verified',
      };

      expect(CustomerOrderPresentation.stage(order), 'payment_verified');
      expect(CustomerOrderPresentation.timeline(order), [
        'awaiting_acceptance',
        'accepted_awaiting_payment',
        'payment_verified',
      ]);
    });

    test('rejection is terminal regardless of fulfillment status', () {
      final order = <String, dynamic>{
        'acceptanceStatus': 'rejected',
        'status': 'pending_payment',
        'rejectionReason': 'Delivery is unavailable for this location.',
      };

      expect(CustomerOrderPresentation.stage(order), 'rejected');
      expect(CustomerOrderPresentation.timeline(order), [
        'awaiting_acceptance',
        'rejected',
      ]);
    });

    test('legacy orders retain their fulfillment status', () {
      final order = <String, dynamic>{'status': 'processing'};

      expect(CustomerOrderPresentation.stage(order), 'processing');
      expect(CustomerOrderPresentation.timeline(order), [
        'pending_payment',
        'payment_verified',
        'processing',
      ]);
    });

    test('uploaded payment appears as the latest timeline stage', () {
      final order = <String, dynamic>{
        'acceptanceStatus': 'accepted',
        'status': 'payment_uploaded',
        'statusHistory': [
          {'status': 'payment_uploaded'},
        ],
      };

      expect(CustomerOrderPresentation.timeline(order), [
        'awaiting_acceptance',
        'accepted_awaiting_payment',
        'payment_uploaded',
      ]);
    });

    test('cancelled order retains completed milestones', () {
      final order = <String, dynamic>{
        'acceptanceStatus': 'accepted',
        'status': 'cancelled',
        'statusHistory': [
          {'status': 'payment_verified'},
          {'status': 'processing'},
          {'status': 'cancelled'},
        ],
      };

      expect(CustomerOrderPresentation.timeline(order), [
        'awaiting_acceptance',
        'accepted_awaiting_payment',
        'payment_verified',
        'processing',
        'cancelled',
      ]);
    });

    test('every known stage has a localized label in both languages', () {
      const stages = [
        'awaiting_acceptance',
        'accepted_awaiting_payment',
        'pending_payment',
        'payment_uploaded',
        'payment_verified',
        'processing',
        'shipped',
        'delivered',
        'rejected',
        'cancelled',
      ];
      for (final stage in stages) {
        final english = CustomerOrderPresentation.label(en, stage);
        final hindi = CustomerOrderPresentation.label(hi, stage);
        expect(english, isNot(contains('_')), reason: stage);
        expect(hindi, isNot(english), reason: stage);
        expect(hindi, isNot(matches(RegExp('[०-९]'))), reason: stage);
      }
      expect(CustomerOrderPresentation.label(en, 'shipped'), 'Shipped');
      expect(CustomerOrderPresentation.label(hi, 'delivered'), 'डिलीवर हो गया');
    });

    test('unknown stages fall back to readable text', () {
      expect(CustomerOrderPresentation.label(en, 'on_hold'), 'on hold');
    });
  });
}
