import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/cart_provider.dart';
import '../l10n/api_error_text.dart';
import '../l10n/l10n.dart';
import 'ui/app_feedback.dart';

/// Wholesalers: sends the whole cart to the Deal Desk as a requirement and
/// shows the result. Returns true when it was sent (the cart is then empty).
Future<bool> sendCartRequirement(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final sent = await ref.read(cartProvider.notifier).sendAsRequirement();
    final message = l10n.cartRequirementSent(sent.length);
    if (context.mounted) {
      showAppSnack(context, message, tone: SnackTone.success);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    showAppSnack(
      context,
      cartRequirementErrorText(context, error),
      tone: SnackTone.error,
    );
    return false;
  }
}

/// Names the cart items that stopped the requirement (negotiation turned off,
/// below the wholesale minimum), otherwise the usual API error text.
String cartRequirementErrorText(BuildContext context, Object error) {
  if (error is DioException) {
    final details = error.response?.data is Map
        ? (error.response!.data as Map)['error']
        : null;
    final extra = details is Map ? details['details'] : null;
    final items = extra is Map ? extra['items'] : null;
    if (items is List) {
      final names = items
          .whereType<Map>()
          .map((item) => (item['name'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty)
          .toList();
      if (names.isNotEmpty) {
        return context.l10n.cartRequirementBlockedItems(names.join(', '));
      }
    }
  }
  return apiErrorText(context, error);
}
