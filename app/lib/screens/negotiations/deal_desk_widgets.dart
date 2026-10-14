// Presentational pieces of the Deal Desk: the inbox row, status chip and
// stepper, the Active/Completed switch, chat bubbles, offer cards and the
// "How Deal Desk works" sheet. Data in, callbacks out: nothing here reads a
// provider or navigates, so the Home screen's Deal Desk tab can reuse them.
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/deal_desk_presentation.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/utils/packing.dart';
import '../../l10n/l10n.dart';
import '../../l10n/pack_text.dart';
import '../../widgets/app_image.dart';
import '../../widgets/ui/ui.dart';

export '../../core/utils/deal_desk_presentation.dart'
    show DealDeskPresentation, DealStatusKind, DealTileAction, DealOrderStatus;

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

/// Chip tone for a deal status.
ChipTone dealStatusTone(DealStatusKind kind) => switch (kind) {
  DealStatusKind.requested => ChipTone.info,
  DealStatusKind.newPrice => ChipTone.warning,
  DealStatusKind.yourCounter => ChipTone.info,
  DealStatusKind.acceptedOrderPending => ChipTone.success,
  DealStatusKind.orderCreated => ChipTone.brand,
  DealStatusKind.declined => ChipTone.error,
  DealStatusKind.expired => ChipTone.neutral,
  DealStatusKind.unknown => ChipTone.neutral,
};

/// "Just now", "5m ago", "3h ago", "2d ago", then "12 Sep".
String dealRelativeTime(BuildContext context, DateTime time) {
  final l10n = context.l10n;
  final local = time.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return l10n.notificationsJustNow;
  if (diff.inMinutes < 60) {
    return l10n.notificationsMinutesAgo('${diff.inMinutes}');
  }
  if (diff.inHours < 24) return l10n.notificationsHoursAgo('${diff.inHours}');
  if (diff.inDays < 7) return l10n.notificationsDaysAgo('${diff.inDays}');
  final code = Localizations.localeOf(context).languageCode;
  return NumberFormatter.ensureEnglishNumerals(
    DateFormat('d MMM', code).format(local),
  );
}

/// "Today", "Yesterday" or "12 Sep 2026" for a chat date separator.
String dealDayLabel(BuildContext context, DateTime time) {
  final l10n = context.l10n;
  final local = time.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final days = today.difference(day).inDays;
  if (days == 0) return l10n.dealToday;
  if (days == 1) return l10n.dealYesterday;
  final code = Localizations.localeOf(context).languageCode;
  return NumberFormatter.ensureEnglishNumerals(
    DateFormat('d MMM yyyy', code).format(local),
  );
}

/// Quantity of a deal for display: "2 Bundles (1,000 m)" for whole packs of a
/// pack product (when [product] carries priceUnit/packing), else "20 units".
String dealQuantityText(
  AppLocalizations l10n,
  Map<dynamic, dynamic>? product,
  int quantity,
) {
  final info = product == null ? PackInfo.none : packInfoOf(product);
  if (info.isPack && quantity > 0 && quantity % info.size == 0) {
    return packQuantityText(l10n, info, quantity);
  }
  return l10n.commonUnitsCount(quantity);
}

DateTime? _parseTime(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

Map<String, dynamic>? _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

/// The product map of a negotiation: `product` in list rows,
/// `productSnapshot` in the detail response.
Map<String, dynamic>? dealProductOf(Map<String, dynamic> negotiation) =>
    _asMap(negotiation['product']) ?? _asMap(negotiation['productSnapshot']);

// ---------------------------------------------------------------------------
// Status chip, needs-reply dot, stepper
// ---------------------------------------------------------------------------

/// [StatusChip] with the deal's readable status label and tone.
class DealStatusChip extends StatelessWidget {
  /// [negotiation] is the deal map as the API returns it. [dense] makes the
  /// chip smaller (for list rows).
  const DealStatusChip({
    super.key,
    required this.negotiation,
    this.dense = false,
  });

  final Map<String, dynamic> negotiation;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final kind = DealDeskPresentation.statusKind(negotiation);
    return StatusChip(
      label: DealDeskPresentation.statusLabel(negotiation, l10n: context.l10n),
      tone: dealStatusTone(kind),
      dense: dense,
    );
  }
}

/// Small teal dot marking a deal that needs the wholesaler's reply.
class DealNeedsReplyDot extends StatelessWidget {
  /// [size] is the dot's diameter.
  const DealNeedsReplyDot({super.key, this.size = 10});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.dealNeedsReply,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Four-step progress: Requested → Price talk → Agreed → Order. Hidden for
/// declined/expired deals (the status chip says it instead).
class DealStatusStepper extends StatelessWidget {
  /// [negotiation] is the deal map; its step comes from
  /// [DealDeskPresentation.stepIndex].
  const DealStatusStepper({super.key, required this.negotiation});

  final Map<String, dynamic> negotiation;

  @override
  Widget build(BuildContext context) {
    final current = DealDeskPresentation.stepIndex(negotiation);
    if (current < 0) return const SizedBox.shrink();
    final l10n = context.l10n;
    final labels = [
      l10n.dealStepRequested,
      l10n.dealStepTalking,
      l10n.dealStepAgreed,
      l10n.dealStepOrder,
    ];
    return Semantics(
      label: labels[current],
      child: ExcludeSemantics(
        child: Column(
          children: [
            Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  _dot(done: i <= current, isCurrent: i == current),
                  if (i < labels.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i < current
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: Text(
                      labels[i],
                      textAlign: i == 0
                          ? TextAlign.start
                          : i == labels.length - 1
                          ? TextAlign.end
                          : TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.jakarta(
                        fontSize: 11,
                        fontWeight: i == current
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: i <= current
                            ? AppColors.primaryDeep
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot({required bool done, required bool isCurrent}) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: done ? AppColors.primary : AppColors.surfaceLight,
        shape: BoxShape.circle,
        border: Border.all(
          color: done ? AppColors.primary : AppColors.borderStrong,
          width: 1.5,
        ),
      ),
      child: done && !isCurrent
          ? const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedTick02,
                size: 12,
                color: Colors.white,
              ),
            )
          : isCurrent
          ? Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Inbox row
// ---------------------------------------------------------------------------

/// One Deal Desk conversation in an inbox list, laid out around a progress
/// tracker: thumbnail, product name (or cart summary) and one line of
/// quantity · latest price · total, then Requested → Price talk → Agreed with
/// the current step named (and "your turn" when DemoMart is waiting), then
/// an optional action button. Declined/expired deals show their status chip
/// in place of the tracker. Relative time and a needs-reply dot sit top
/// right.
class DealInboxTile extends StatelessWidget {
  /// [negotiation]: a row from `GET /negotiations` (the detail response works
  /// too). Reads `product`/`productSnapshot`, optional `items`,
  /// `negotiationNumber`, `status`, `currentOfferBy`, `requestedQuantity`,
  /// `requestedPricePerUnit`, `currentPricePerUnit`, `currentTotalPrice`,
  /// `canPay`, `orderId` and `updatedAt`/`createdAt`.
  ///
  /// [onTap] opens the conversation.
  ///
  /// [onAction] is called with the row's [DealTileAction] when its button is
  /// pressed (respond, viewOrder, viewDetails). Without it no
  /// button is shown. Passive actions (underReview, declined, expired) never
  /// show a button; "Under Review" is shown as a quiet line instead.
  ///
  /// [action] overrides the derived action; [orderShortcut] is forwarded to
  /// [DealDeskPresentation.tileAction] (offer "View Order" for deals with an
  /// order). [actionLabel] overrides the button label and [actionLoading]
  /// shows a spinner in it.
  ///
  /// [needsReply] overrides the derived needs-reply state (dot, bold title);
  /// [unread] adds the dot for another reason, e.g. an unseen message.
  const DealInboxTile({
    super.key,
    required this.negotiation,
    this.onTap,
    this.onAction,
    this.action,
    this.orderShortcut = false,
    this.actionLabel,
    this.actionLoading = false,
    this.needsReply,
    this.unread = false,
  });

  final Map<String, dynamic> negotiation;
  final VoidCallback? onTap;
  final ValueChanged<DealTileAction>? onAction;
  final DealTileAction? action;
  final bool orderShortcut;
  final String? actionLabel;
  final bool actionLoading;
  final bool? needsReply;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kind = DealDeskPresentation.statusKind(negotiation);
    final replyNeeded =
        needsReply ?? DealDeskPresentation.needsReply(negotiation);
    final showDot = replyNeeded || unread;
    final product = dealProductOf(negotiation);
    final items = negotiation['items'] is List
        ? (negotiation['items'] as List).whereType<Map>().toList()
        : const <Map>[];
    final firstItem = items.isNotEmpty
        ? _asMap(items.first['product']) ?? _asMap(items.first)
        : null;
    final titleSource = product ?? firstItem;
    final name = localizedName(
      context,
      titleSource,
      fallback: l10n.negotiationsUnknownProduct,
    );
    final imageUrl = (titleSource?['image'] ?? '').toString();
    final quantity = DealDeskPresentation.quantityOf(negotiation);
    final suffix = DealDeskPresentation.unitSuffix(product, l10n);
    final price = negotiation['currentPricePerUnit'];
    final total = negotiation['currentTotalPrice'];
    // One line: quantity · latest price · total.
    final metaParts = <String>[
      if (items.length > 1)
        l10n.commonItemsCount(items.length)
      else
        dealQuantityText(l10n, product, quantity),
      if (price != null) '${DealDeskPresentation.rupees(price)}$suffix',
      if (total != null) DealDeskPresentation.rupees(total),
    ];
    final time =
        _parseTime(negotiation['updatedAt']) ??
        _parseTime(negotiation['createdAt']);
    final resolvedAction =
        action ??
        DealDeskPresentation.tileAction(
          negotiation,
          orderShortcut: orderShortcut,
        );

    final closed =
        kind == DealStatusKind.declined || kind == DealStatusKind.expired;

    return Pressable(
      onTap: onTap,
      color: AppColors.surfaceLight,
      scale: 0.985,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      semanticLabel: name,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: AppColors.gray50,
                    child: AppImage(
                      imageUrl: imageUrl,
                      blurHash: titleSource?['blurHash']?.toString(),
                      category: (titleSource?['category'] ?? '').toString(),
                      name: name,
                      width: 48,
                      height: 48,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 15,
                          fontWeight: showDot
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        metaParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (time != null)
                      Text(
                        dealRelativeTime(context, time),
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          fontWeight: showDot
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: showDot
                              ? AppColors.primaryDeep
                              : AppColors.textTertiary,
                        ),
                      ),
                    if (showDot) ...[
                      const SizedBox(height: 8),
                      const DealNeedsReplyDot(),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (closed)
              DealStatusChip(negotiation: negotiation, dense: true)
            else
              _DealTrack(kind: kind, yourTurn: replyNeeded),
            // Accepted before orders were created on acceptance: DemoMart
            // creates the order from the admin panel, so nothing to tap.
            if (kind == DealStatusKind.acceptedOrderPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedClock01,
                    size: 16,
                    color: AppColors.primaryDeep,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.dealOrderBeingPrepared,
                      style: AppFonts.jakarta(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (onAction != null && _hasButton(resolvedAction)) ...[
              const SizedBox(height: 14),
              _actionButton(context, resolvedAction),
            ],
          ],
        ),
      ),
    );
  }

  static bool _hasButton(DealTileAction action) => switch (action) {
    DealTileAction.respond ||
    DealTileAction.viewOrder ||
    DealTileAction.viewDetails => true,
    DealTileAction.underReview ||
    DealTileAction.declined ||
    DealTileAction.expired => false,
  };

  Widget _actionButton(BuildContext context, DealTileAction resolved) {
    final l10n = context.l10n;
    final (
      String label,
      IconData? icon,
      AppButtonVariant variant,
    ) = switch (resolved) {
      DealTileAction.respond => (
        l10n.homeRespondToCounter,
        HugeIcons.strokeRoundedBubbleChat,
        AppButtonVariant.primary,
      ),
      DealTileAction.viewOrder => (
        l10n.dealViewOrder,
        HugeIcons.strokeRoundedTruckDelivery,
        AppButtonVariant.tonal,
      ),
      // Light teal: solid teal is kept for "Respond", which needs you.
      _ => (l10n.commonViewDetails, null, AppButtonVariant.tonal),
    };
    return AppButton(
      label: actionLabel ?? label,
      icon: icon,
      variant: variant,
      size: AppButtonSize.medium,
      loading: actionLoading,
      pill: true,
      onPressed: () => onAction?.call(resolved),
    );
  }
}

/// Requested → Price talk → Agreed, for an inbox card: done steps are
/// green, the current one is a ring (amber while it's your turn, teal once
/// agreed) and named underneath. Deals with an order count as agreed; the
/// app's deal flow ends there.
class _DealTrack extends StatelessWidget {
  const _DealTrack({required this.kind, required this.yourTurn});

  final DealStatusKind kind;
  final bool yourTurn;

  int get _current => switch (kind) {
    DealStatusKind.requested => 0,
    DealStatusKind.newPrice || DealStatusKind.yourCounter => 1,
    _ => 2,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = _current;
    final labels = [
      l10n.dealStepRequested,
      l10n.dealStepTalking,
      l10n.dealStepAgreed,
    ];
    final ringColor = yourTurn ? AppColors.accent : AppColors.primary;
    // The current step's name, with what it's waiting on.
    final currentLabel = yourTurn
        ? '${labels[current]} · ${l10n.dealYourTurn}'
        : labels[current];

    Widget dot(int i) {
      final done = i < current;
      final isCurrent = i == current;
      if (isCurrent) {
        final finished = current == labels.length - 1;
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: finished ? AppColors.primary : AppColors.surfaceLight,
            shape: BoxShape.circle,
            border: Border.all(
              color: finished ? AppColors.primarySoft : ringColor,
              width: 3.5,
            ),
          ),
        );
      }
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: done ? AppColors.primary : AppColors.border,
          shape: BoxShape.circle,
        ),
      );
    }

    return Semantics(
      label: currentLabel,
      child: ExcludeSemantics(
        child: Column(
          children: [
            Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  dot(i),
                  if (i < labels.length - 1)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i < current
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 7),
            // Each name sits under its own dot (start, middle, end), so the
            // longer "Price talk · your turn" still fits in the middle.
            SizedBox(
              height: 16,
              child: Stack(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Align(
                      alignment: Alignment(-1 + 2 * i / (labels.length - 1), 0),
                      child: Text(
                        i == current ? currentLabel : labels[i],
                        maxLines: 1,
                        style: AppFonts.jakarta(
                          fontSize: 11.5,
                          fontWeight: i == current
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: i == current
                              ? (yourTurn
                                    ? AppColors.warning
                                    : AppColors.primaryDeep)
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder shaped like a [DealInboxTile], for loading lists.
class DealInboxSkeleton extends StatelessWidget {
  /// No options: one skeleton row with the tile's proportions.
  const DealInboxSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: const SkeletonShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Skeleton(width: 48, height: 48, radius: AppRadius.md),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(height: 14),
                      SizedBox(height: 8),
                      Skeleton(width: 170, height: 11),
                    ],
                  ),
                ),
                SizedBox(width: 24),
                Skeleton(width: 36, height: 11),
              ],
            ),
            SizedBox(height: 14),
            // The progress tracker: three dots on a line, names under them.
            Row(
              children: [
                Skeleton(width: 12, height: 12, radius: AppRadius.pill),
                Expanded(child: Skeleton(height: 3)),
                Skeleton(width: 18, height: 18, radius: AppRadius.pill),
                Expanded(child: Skeleton(height: 3)),
                Skeleton(width: 12, height: 12, radius: AppRadius.pill),
              ],
            ),
            SizedBox(height: 7),
            Row(
              children: [
                Skeleton(width: 56, height: 10),
                Spacer(),
                Skeleton(width: 60, height: 10),
                Spacer(),
                Skeleton(width: 44, height: 10),
              ],
            ),
            SizedBox(height: 14),
            Skeleton(height: 44, radius: AppRadius.pill),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active / Completed switch
// ---------------------------------------------------------------------------

/// Two (or more) segment switch on a pill track, used for the Deal Desk's
/// Active / Completed lists. The light teal pill under the selected segment
/// slides between segments; pass the [controller] of the swipeable lists it
/// switches and the pill follows the finger too.
class DealSegmentedControl extends StatelessWidget {
  /// [labels] are the segment names, [selectedIndex] the current one and
  /// [onChanged] is called with the tapped index. [counts] (same length as
  /// [labels], optional) shows a number after each label; 0 or null hides it.
  const DealSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.counts,
    this.controller,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<int?>? counts;
  final PageController? controller;

  @override
  Widget build(BuildContext context) {
    final pages = controller;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: const ShapeDecoration(
        color: AppColors.surfaceLight,
        shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      ),
      child: pages == null
          ? TweenAnimationBuilder<double>(
              tween: Tween(end: selectedIndex.toDouble()),
              duration: AppMotion.of(context, AppMotion.slow),
              curve: AppMotion.standard,
              builder: (context, position, _) => _track(position),
            )
          : AnimatedBuilder(
              animation: pages,
              builder: (context, _) => _track(_pageOf(pages)),
            ),
    );
  }

  /// Where the lists are, in pages (fractional mid-swipe).
  double _pageOf(PageController pages) {
    if (pages.hasClients && pages.positions.length == 1) {
      return pages.page ?? selectedIndex.toDouble();
    }
    return selectedIndex.toDouble();
  }

  Widget _track(double position) {
    final pill = position.clamp(0.0, labels.length - 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / labels.length;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: pill * width,
              top: 0,
              bottom: 0,
              width: width,
              child: const DecoratedBox(
                decoration: ShapeDecoration(
                  color: AppColors.primarySoft,
                  shape: StadiumBorder(),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: _segment(i, (1 - (pill - i).abs()).clamp(0.0, 1.0)),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Segment [i]; [t] is how much the pill covers it (1 = fully selected).
  Widget _segment(int i, double t) {
    final count = counts?.elementAtOrNull(i) ?? 0;
    return MergeSemantics(
      child: Semantics(
        selected: i == selectedIndex,
        button: true,
        child: Material(
          color: Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: i == selectedIndex ? null : () => onChanged(i),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.jakarta(
                        fontSize: 14,
                        fontWeight: t > 0.5 ? FontWeight.w700 : FontWeight.w600,
                        color: Color.lerp(
                          AppColors.textSecondary,
                          AppColors.primaryDeep,
                          t,
                        ),
                      ),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: AppText.price(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color.lerp(
                          AppColors.textTertiary,
                          AppColors.primaryDeep,
                          t,
                        )!,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat pieces
// ---------------------------------------------------------------------------

/// Centered day label between chat messages ("Today", "Yesterday", date).
class DealDateSeparator extends StatelessWidget {
  /// [label] is the text to show, usually from [dealDayLabel].
  const DealDateSeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            style: AppFonts.jakarta(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain chat message. Outgoing messages sit on the right on a soft teal
/// fill; incoming ones on the left in a white bubble with a border.
class DealMessageBubble extends StatelessWidget {
  /// [text] is the message. [outgoing] is true for the wholesaler's own
  /// messages. [senderLabel] is shown above the first bubble of a group
  /// ([isFirstInGroup]); [time] ("4:05 PM"), the read tick ([read]) and the
  /// sending clock ([sending]) are shown under the last bubble of a group
  /// ([isLastInGroup]).
  const DealMessageBubble({
    super.key,
    required this.text,
    required this.outgoing,
    this.senderLabel,
    this.time,
    this.read = false,
    this.sending = false,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  final String text;
  final bool outgoing;
  final String? senderLabel;
  final String? time;
  final bool read;
  final bool sending;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  @override
  Widget build(BuildContext context) {
    const big = Radius.circular(AppRadius.lg);
    const small = Radius.circular(6);
    final radius = outgoing
        ? BorderRadius.only(
            topLeft: big,
            bottomLeft: big,
            topRight: isFirstInGroup ? big : small,
            bottomRight: isLastInGroup ? const Radius.circular(4) : small,
          )
        : BorderRadius.only(
            topRight: big,
            bottomRight: big,
            topLeft: isFirstInGroup ? big : small,
            bottomLeft: isLastInGroup ? const Radius.circular(4) : small,
          );
    final showMeta =
        isLastInGroup && ((time?.isNotEmpty ?? false) || read || sending);

    return Padding(
      padding: EdgeInsets.only(bottom: isLastInGroup ? 10 : 3),
      child: Column(
        crossAxisAlignment: outgoing
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (isFirstInGroup && (senderLabel?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Text(
                senderLabel!,
                style: AppFonts.jakarta(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: outgoing
                      ? AppColors.textSecondary
                      : AppColors.primaryDeep,
                ),
              ),
            ),
          FractionallySizedBox(
            widthFactor: 0.8,
            alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
            child: Align(
              alignment: outgoing
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                decoration: BoxDecoration(
                  color: outgoing
                      ? AppColors.primarySoft
                      : AppColors.surfaceLight,
                  borderRadius: radius,
                  border: outgoing ? null : Border.all(color: AppColors.border),
                ),
                child: Text(
                  text,
                  style: AppFonts.jakarta(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          if (showMeta)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (time?.isNotEmpty ?? false)
                    Text(
                      time!,
                      style: AppFonts.jakarta(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  if (outgoing && sending) ...[
                    const SizedBox(width: 4),
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedClock01,
                      size: 12,
                      color: AppColors.textTertiary,
                    ),
                  ] else if (outgoing && read) ...[
                    const SizedBox(width: 4),
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedTickDouble02,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A price event in the chat (requirement sent, new price, accepted,
/// declined) as a structured card: what, for how many, per-unit price, total
/// and the note that came with it.
class DealOfferCard extends StatelessWidget {
  /// [title] names the event ("New Price from DemoMart") and [icon]/[tone]
  /// colour it. [fromPlatform] puts the card on the left (DemoMart) or right
  /// (you). [senderLabel] is shown above the card. [itemName] and
  /// [quantityText] describe what is priced; [pricePerUnit] (already
  /// formatted, e.g. "₹18,500") with [unitSuffix] ("/unit") and [total]
  /// ("₹3,70,000") are shown when given. [message] is the note sent with the
  /// price and [time] the formatted time. [highlight] turns the card solid
  /// teal with moving dither light and white text (the accepted deal).
  const DealOfferCard({
    super.key,
    required this.title,
    required this.icon,
    required this.tone,
    required this.fromPlatform,
    required this.itemName,
    this.senderLabel,
    this.quantityText,
    this.pricePerUnit,
    this.unitSuffix,
    this.total,
    this.message,
    this.time,
    this.highlight = false,
  });

  final String title;
  final IconData icon;
  final ChipTone tone;
  final bool fromPlatform;
  final String itemName;
  final String? senderLabel;
  final String? quantityText;
  final String? pricePerUnit;
  final String? unitSuffix;
  final String? total;
  final String? message;
  final String? time;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final toneColor = highlight
        ? Colors.white
        : switch (tone) {
            ChipTone.brand || ChipTone.success => AppColors.primaryDeep,
            ChipTone.info => AppColors.secondary,
            ChipTone.warning => AppColors.warning,
            ChipTone.error => AppColors.error,
            ChipTone.accent => AppColors.accent,
            ChipTone.neutral => AppColors.textSecondary,
          };
    final toneBg = highlight
        ? AppColors.primaryDeep.withValues(alpha: 0.35)
        : switch (tone) {
            ChipTone.brand || ChipTone.success => AppColors.primarySoft,
            ChipTone.info => AppColors.infoSoft,
            ChipTone.warning => AppColors.warningSoft,
            ChipTone.error => AppColors.errorSoft,
            ChipTone.accent => AppColors.accentSoft,
            ChipTone.neutral => AppColors.gray100,
          };
    // Text colours: white on the teal highlight, the usual greys otherwise.
    final ink = highlight ? Colors.white : AppColors.textPrimary;
    final softInk = highlight
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.textTertiary;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: toneBg,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              HugeIcon(icon: icon, size: 16, color: toneColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: toneColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                itemName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              if (quantityText?.isNotEmpty ?? false) ...[
                const SizedBox(height: 2),
                Text(
                  quantityText!,
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: softInk,
                  ),
                ),
              ],
              if (pricePerUnit != null || total != null) ...[
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: highlight
                      ? Colors.white.withValues(alpha: 0.24)
                      : null,
                ),
                const SizedBox(height: 4),
                if (pricePerUnit != null)
                  SummaryRow(
                    label: l10n.dealOfferPerUnit,
                    value: '$pricePerUnit${unitSuffix ?? ''}',
                    labelColor: highlight ? softInk : null,
                    valueColor: highlight ? ink : null,
                  ),
                if (total != null)
                  SummaryRow(
                    label: l10n.commonTotal,
                    value: total!,
                    labelColor: highlight ? softInk : null,
                    valueColor: ink,
                  ),
              ],
              if (message?.isNotEmpty ?? false) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: highlight
                        ? Colors.white.withValues(alpha: 0.14)
                        : AppColors.gray50,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    message!,
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      color: ink,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (time?.isNotEmpty ?? false) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    time!,
                    style: AppFonts.jakarta(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: softInk,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: fromPlatform
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          if (senderLabel?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Text(
                senderLabel!,
                style: AppFonts.jakarta(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fromPlatform
                      ? AppColors.primaryDeep
                      : AppColors.textSecondary,
                ),
              ),
            ),
          FractionallySizedBox(
            widthFactor: 0.86,
            alignment: fromPlatform ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              decoration: highlight
                  ? BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryDeep],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    )
                  : BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
              clipBehavior: Clip.antiAlias,
              child: highlight
                  ? Stack(
                      children: [
                        const Positioned.fill(child: DitherGlow(opacity: 0.14)),
                        body,
                      ],
                    )
                  : body,
            ),
          ),
        ],
      ),
    );
  }
}

/// "DemoMart is typing" bubble with three softly pulsing dots (a live
/// signal, so it loops while shown; static when motion is reduced).
class DealTypingIndicator extends StatefulWidget {
  /// [label] is the full sentence, e.g. "DemoMart is typing...".
  const DealTypingIndicator({super.key, required this.label});

  final String label;

  @override
  State<DealTypingIndicator> createState() => _DealTypingIndicatorState();
}

class _DealTypingIndicatorState extends State<DealTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: widget.label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(
                            alpha: _dotAlpha(i),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _dotAlpha(int index) {
    if (!_controller.isAnimating) return 0.7;
    final phase = (_controller.value * 3 - index) % 3;
    return phase < 1 ? 0.35 + 0.65 * (1 - (phase - 0.5).abs() * 2) : 0.35;
  }
}

// ---------------------------------------------------------------------------
// "How Deal Desk works"
// ---------------------------------------------------------------------------

const _explainerSeenKey = 'deal_desk_explainer_seen_v1';

/// Opens the "How Deal Desk works" bottom sheet: three short steps from the
/// Negotiation Guide and a "Got it" button.
Future<void> showDealDeskExplainer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final steps = [
        (l10n.guideStep1Title, l10n.guideStep1Body),
        (l10n.guideStep2Title, l10n.guideStep2Body),
        (l10n.guideStep3Title, l10n.guideStep3Body),
      ];
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 10),
              Text(
                l10n.dealExplainerTitle,
                style: AppFonts.jakarta(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.guideHowItWorksBody,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: AppText.price(
                            fontSize: 14,
                            color: AppColors.primaryDeep,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              steps[i].$1,
                              style: AppFonts.jakarta(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              steps[i].$2,
                              style: AppFonts.jakarta(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              AppButton(
                label: l10n.commonGotIt,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Shows [showDealDeskExplainer] the first time it is called on this device
/// and remembers that (shared_preferences). Later calls do nothing.
Future<void> showDealDeskExplainerOnce(BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_explainerSeenKey) == true) return;
    await prefs.setBool(_explainerSeenKey, true);
  } catch (_) {
    return;
  }
  if (!context.mounted) return;
  await showDealDeskExplainer(context);
}
