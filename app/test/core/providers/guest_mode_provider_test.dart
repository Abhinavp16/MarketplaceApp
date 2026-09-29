import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/providers/guest_mode_provider.dart';

void main() {
  group('customer preview audience', () {
    test('wholesaler is presented as customer while preview is active', () {
      expect(
        isEffectiveWholesaler(
          accountIsWholesaler: true,
          isCustomerPreview: false,
        ),
        isTrue,
      );
      expect(
        isEffectiveWholesaler(
          accountIsWholesaler: true,
          isCustomerPreview: true,
        ),
        isFalse,
      );
      expect(
        isEffectiveWholesaler(
          accountIsWholesaler: false,
          isCustomerPreview: true,
        ),
        isFalse,
      );
    });

    test('preview uses retail price and normal mode uses role price', () {
      final product = <String, dynamic>{'price': 80, 'retailPrice': 120};

      expect(catalogPriceForAudience(product, isCustomerPreview: true), 120);
      expect(catalogPriceForAudience(product, isCustomerPreview: false), 80);
    });

    test('notifier enters and exits preview without changing other state', () {
      final notifier = GuestModeNotifier();
      expect(notifier.state, isFalse);

      notifier.enableGuestMode();
      expect(notifier.state, isTrue);

      notifier.disableGuestMode();
      expect(notifier.state, isFalse);
    });
  });
}
