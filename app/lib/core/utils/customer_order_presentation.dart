import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../widgets/ui/ui_basics.dart' show ChipTone;
import '../theme/app_theme.dart';

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
        return const Color(0xFF2563EB);
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

  // ---------------------------------------------------------------------------
  // Redesign helpers. They only add information; the outputs above are
  // unchanged.

  /// True when the order ended without being delivered (rejected / cancelled).
  static bool isStopped(String stage) =>
      stage == 'rejected' || stage == 'cancelled';

  /// Kit chip tone for an order [stage].
  static ChipTone chipTone(String stage) {
    switch (stage) {
      case 'awaiting_acceptance':
      case 'pending_payment':
      case 'accepted_awaiting_payment':
        return ChipTone.warning;
      case 'payment_uploaded':
      case 'payment_verified':
      case 'processing':
      case 'shipped':
        return ChipTone.info;
      case 'delivered':
        return ChipTone.success;
      case 'rejected':
      case 'cancelled':
        return ChipTone.error;
      default:
        return ChipTone.neutral;
    }
  }

  /// Brand-palette colour for an order [stage] (the redesign's one colour per
  /// state: amber waiting, blue moving, green done, red stopped).
  static Color toneColor(String stage) {
    switch (chipTone(stage)) {
      case ChipTone.warning:
        return AppColors.warning;
      case ChipTone.info:
        return AppColors.secondary;
      case ChipTone.success:
      case ChipTone.brand:
        return AppColors.primary;
      case ChipTone.error:
        return AppColors.error;
      case ChipTone.accent:
        return AppColors.accent;
      case ChipTone.neutral:
        return AppColors.textTertiary;
    }
  }

  /// HugeIcons glyph for an order [stage].
  static IconData hugeIcon(String stage) {
    switch (stage) {
      case 'awaiting_acceptance':
        return HugeIcons.strokeRoundedClock01;
      case 'accepted_awaiting_payment':
        return HugeIcons.strokeRoundedTaskDone01;
      case 'pending_payment':
        return HugeIcons.strokeRoundedWallet01;
      case 'payment_uploaded':
        return HugeIcons.strokeRoundedHourglass;
      case 'payment_verified':
        return HugeIcons.strokeRoundedSecurityCheck;
      case 'processing':
        return HugeIcons.strokeRoundedPackage;
      case 'shipped':
        return HugeIcons.strokeRoundedDeliveryTruck01;
      case 'delivered':
        return HugeIcons.strokeRoundedPackageDelivered;
      case 'rejected':
        return HugeIcons.strokeRoundedCancelCircle;
      case 'cancelled':
        return HugeIcons.strokeRoundedCancel01;
      default:
        return HugeIcons.strokeRoundedInformationCircle;
    }
  }

  /// When the order reached [stage], if the order records it.
  static DateTime? stageTime(Map<String, dynamic> order, String stage) {
    dynamic value;
    switch (stage) {
      case 'awaiting_acceptance':
        value = order['createdAt'];
      case 'accepted_awaiting_payment':
        value = order['acceptedAt'];
      case 'rejected':
        value = order['rejectedAt'];
      default:
        final history = order['statusHistory'];
        if (history is List) {
          for (final item in history) {
            if (item is Map && item['status']?.toString() == stage) {
              value = item['timestamp'];
              break;
            }
          }
        }
        if (value == null && stage == 'shipped') value = order['shippedAt'];
        if (value == null && stage == 'delivered') value = order['deliveredAt'];
        if (value == null && stage == 'pending_payment') {
          value = order['createdAt'];
        }
    }
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    return parsed?.toLocal();
  }

  /// The whole journey of an order in order: steps already reached, the
  /// current one and the ones still to come. A rejected or cancelled order
  /// ends in a [OrderStepState.stopped] step instead of the upcoming ones.
  static List<OrderJourneyStep> journey(Map<String, dynamic> order) {
    final currentStage = stage(order);
    final reached = timeline(order);

    OrderJourneyStep step(String s, OrderStepState state) =>
        OrderJourneyStep(stage: s, state: state, at: stageTime(order, s));

    if (isStopped(currentStage)) {
      return [
        for (final s in reached)
          step(
            s,
            s == currentStage ? OrderStepState.stopped : OrderStepState.done,
          ),
      ];
    }

    final acceptance = acceptanceStatus(order);
    final full = <String>[
      if (acceptance == 'accepted' || acceptance == 'pending') ...[
        'awaiting_acceptance',
        'accepted_awaiting_payment',
      ] else
        'pending_payment',
      if (reached.contains('payment_uploaded')) 'payment_uploaded',
      'payment_verified',
      'processing',
      'shipped',
      'delivered',
    ];
    final index = full.indexOf(currentStage);
    return [
      for (var i = 0; i < full.length; i++)
        step(
          full[i],
          index < 0
              ? (i == 0 ? OrderStepState.current : OrderStepState.upcoming)
              : i < index
              ? OrderStepState.done
              : i == index
              ? (full[i] == 'delivered'
                    ? OrderStepState.done
                    : OrderStepState.current)
              : OrderStepState.upcoming,
        ),
    ];
  }

  /// Share of the journey reached so far, 0–1 (1 when delivered or stopped).
  static double progress(Map<String, dynamic> order) {
    final steps = journey(order);
    if (steps.isEmpty) return 0;
    final reachedCount = steps
        .where((s) => s.state != OrderStepState.upcoming)
        .length;
    return reachedCount / steps.length;
  }

  /// Text for the "what you need to do" banner when the order is waiting on
  /// the customer, otherwise null. Uses the app's existing guide copy.
  static String? customerAction(AppLocalizations l10n, String stage) {
    switch (stage) {
      case 'accepted_awaiting_payment':
        return l10n.guideStep4Body;
      case 'pending_payment':
        return l10n.guideStep3Body;
      default:
        return null;
    }
  }
}

/// Where an order stands on one step of its journey.
enum OrderStepState { done, current, upcoming, stopped }

/// One step of [CustomerOrderPresentation.journey].
class OrderJourneyStep {
  const OrderJourneyStep({required this.stage, required this.state, this.at});

  /// Stage key, as used by [CustomerOrderPresentation.label].
  final String stage;
  final OrderStepState state;

  /// When the step was reached, if known.
  final DateTime? at;
}
