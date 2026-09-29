import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

class CustomerOrderPresentation {
  static String acceptanceStatus(Map<String, dynamic> order) =>
      order['acceptanceStatus']?.toString().toLowerCase() ?? '';

  static String stage(Map<String, dynamic> order) {
    final acceptance = acceptanceStatus(order);
    if (acceptance == 'rejected') return 'rejected';
    if (acceptance == 'pending') return 'awaiting_acceptance';

    final fulfillment = order['status']?.toString() ?? 'pending_payment';
    if (acceptance == 'accepted' && fulfillment == 'pending_payment') {
      return 'accepted_awaiting_payment';
    }
    return fulfillment;
  }

  /// Localized customer-facing label for an order [stage] (see [stage]).
  static String label(AppLocalizations l10n, String stage) {
    switch (stage) {
      case 'awaiting_acceptance':
        return l10n.statusAwaitingAcceptance;
      case 'accepted_awaiting_payment':
        return l10n.statusAcceptedAwaitingPayment;
      case 'pending_payment':
        return l10n.statusPendingPayment;
      case 'payment_uploaded':
        return l10n.statusPaymentUploaded;
      case 'payment_verified':
        return l10n.statusPaymentVerified;
      case 'processing':
        return l10n.statusProcessing;
      case 'shipped':
        return l10n.statusShipped;
      case 'delivered':
        return l10n.statusDelivered;
      case 'rejected':
        return l10n.statusRejected;
      case 'cancelled':
        return l10n.statusCancelled;
      default:
        return stage.replaceAll('_', ' ');
    }
  }

  static Color color(String stage) {
    switch (stage) {
      case 'awaiting_acceptance':
        return const Color(0xFFD97706);
      case 'accepted_awaiting_payment':
        return const Color(0xFF0F766E);
      case 'pending_payment':
        return const Color(0xFFF59E0B);
      case 'payment_uploaded':
        return const Color(0xFF6366F1);
      case 'payment_verified':
        return const Color(0xFF0F766E);
      case 'processing':
        return const Color(0xFF7C3AED);
      case 'shipped':
        return const Color(0xFF0284C7);
      case 'delivered':
        return const Color(0xFF16A34A);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  static IconData icon(String stage) {
    switch (stage) {
      case 'awaiting_acceptance':
        return Icons.schedule_rounded;
      case 'accepted_awaiting_payment':
        return Icons.task_alt_rounded;
      case 'pending_payment':
        return Icons.access_time_rounded;
      case 'payment_uploaded':
        return Icons.hourglass_top_rounded;
      case 'payment_verified':
        return Icons.verified_rounded;
      case 'processing':
        return Icons.inventory_2_rounded;
      case 'shipped':
        return Icons.local_shipping_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.block_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  static List<String> timeline(Map<String, dynamic> order) {
    final currentStage = stage(order);
    if (currentStage == 'rejected') {
      return const ['awaiting_acceptance', 'rejected'];
    }
    if (currentStage == 'awaiting_acceptance') {
      return const ['awaiting_acceptance'];
    }

    final acceptance = acceptanceStatus(order);
    final history = order['statusHistory'] is List
        ? order['statusHistory'] as List
        : const [];
    bool hasHistory(String status) => history.any(
      (item) => item is Map && item['status']?.toString() == status,
    );
    final stages = <String>[
      if (acceptance == 'accepted') ...[
        'awaiting_acceptance',
        'accepted_awaiting_payment',
      ] else
        'pending_payment',
      if (currentStage == 'payment_uploaded' || hasHistory('payment_uploaded'))
        'payment_uploaded',
      'payment_verified',
      'processing',
      'shipped',
      'delivered',
    ];
    if (currentStage == 'cancelled') {
      final completed = <String>[
        if (acceptance == 'accepted') ...[
          'awaiting_acceptance',
          'accepted_awaiting_payment',
        ] else
          'pending_payment',
        for (final status in const [
          'payment_uploaded',
          'payment_verified',
          'processing',
          'shipped',
          'delivered',
        ])
          if (hasHistory(status)) status,
        'cancelled',
      ];
      return completed;
    }

    final index = stages.indexOf(currentStage);
    return index < 0 ? stages : stages.take(index + 1).toList();
  }
}
