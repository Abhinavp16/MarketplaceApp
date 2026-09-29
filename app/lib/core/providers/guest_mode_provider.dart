import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';

bool isEffectiveWholesaler({
  required bool accountIsWholesaler,
  required bool isCustomerPreview,
}) => accountIsWholesaler && !isCustomerPreview;

dynamic catalogPriceForAudience(
  Map<String, dynamic> product, {
  required bool isCustomerPreview,
}) {
  return isCustomerPreview
      ? product['retailPrice'] ?? product['price'] ?? 0
      : product['price'] ?? product['retailPrice'] ?? 0;
}

/// Manages the guest mode state for viewing the app as a customer
class GuestModeNotifier extends StateNotifier<bool> {
  GuestModeNotifier() : super(false);

  void enableGuestMode() {
    state = true;
  }

  void disableGuestMode() {
    state = false;
  }

  bool isGuestMode() => state;
}

final guestModeProvider = StateNotifierProvider<GuestModeNotifier, bool>((ref) {
  return GuestModeNotifier();
});

final effectiveIsWholesalerProvider = Provider<bool>((ref) {
  return isEffectiveWholesaler(
    accountIsWholesaler: ref.watch(authProvider).user?.isWholesaler == true,
    isCustomerPreview: ref.watch(guestModeProvider),
  );
});
