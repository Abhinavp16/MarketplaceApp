import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import 'number_formatter.dart';
import 'packing.dart';

class DealDeskPresentation {
  static bool hasLinkedOrder(Map<String, dynamic> negotiation) {
    final orderRef = negotiation['orderId'];
    final value = orderRef is Map
        ? (orderRef['_id'] ?? orderRef['id'])
        : orderRef;
    final orderId = value?.toString().trim() ?? '';
    return orderId.isNotEmpty && orderId.toLowerCase() != 'null';
  }

  // Order states after payment is marked; the deal is then done.
  static const _settledOrderStatuses = {
    'payment_verified',
    'processing',
    'shipped',
    'delivered',
    'cancelled',
  };

  /// Completed tab: declined/expired deals, and deals whose order is paid,
  /// shipped, delivered or cancelled. Everything else is still Active.
  static bool isCompleted(Map<String, dynamic> negotiation) {
    final status = negotiation['status']?.toString().toLowerCase() ?? '';
    if (status == 'rejected' || status == 'expired') return true;
    if (!hasLinkedOrder(negotiation)) return false;
    final orderStatus = negotiation['orderStatus']?.toString().toLowerCase();
    return _settledOrderStatuses.contains(orderStatus);
  }

  /// Order status of a negotiation/deal, or null when no order is involved.
  static DealOrderStatus? orderStatus(Map<String, dynamic> negotiation) {
    final status = negotiation['status']?.toString().toLowerCase() ?? '';
    if (status == 'converted' || hasLinkedOrder(negotiation)) {
      return DealOrderStatus.orderCreated;
    }
    if (status == 'accepted') return DealOrderStatus.acceptedOrderPending;
    return null;
  }

  /// Label for [orderStatus]. Pass [l10n] (`context.l10n`) for the current
  /// language; without it the English label is returned.
  static String? orderStatusLabel(
    Map<String, dynamic> negotiation, {
    AppLocalizations? l10n,
  }) {
    final status = orderStatus(negotiation);
    if (status == null) return null;
    final text = l10n ?? lookupAppLocalizations(const Locale('en'));
    switch (status) {
      case DealOrderStatus.orderCreated:
        return text.statusDealOrderCreated;
      case DealOrderStatus.acceptedOrderPending:
        return text.statusDealAcceptedOrderPending;
    }
  }

  // ---- Deal Desk inbox and chat helpers (presentation only) ----

  static String _status(Map<String, dynamic> negotiation) =>
      negotiation['status']?.toString().toLowerCase() ?? 'pending';

  static String _offerBy(Map<String, dynamic> negotiation) =>
      negotiation['currentOfferBy']?.toString() ?? '';

  /// Pending or countered: the deal is still being talked about.
  static bool isActive(Map<String, dynamic> negotiation) =>
      const {'pending', 'countered'}.contains(_status(negotiation));

  /// DemoMart sent the latest price and is waiting for the wholesaler.
  static bool needsReply(Map<String, dynamic> negotiation) =>
      _status(negotiation) == 'countered' && _offerBy(negotiation) == 'admin';

  /// A copy of [deals] with the ones that need a reply first. The order within
  /// each group is kept (the API already sorts newest first).
  static List<Map<String, dynamic>> sortNeedsReplyFirst(
    Iterable<Map<String, dynamic>> deals,
  ) {
    final list = deals.toList();
    return [
      ...list.where(needsReply),
      ...list.where((deal) => !needsReply(deal)),
    ];
  }

  /// Readable status of a deal, one per state the wholesaler can be in.
  static DealStatusKind statusKind(Map<String, dynamic> negotiation) {
    final status = _status(negotiation);
    if (orderStatus(negotiation) == DealOrderStatus.orderCreated &&
        status != 'rejected' &&
        status != 'expired') {
      return DealStatusKind.orderCreated;
    }
    switch (status) {
      case 'pending':
        return DealStatusKind.requested;
      case 'countered':
        return _offerBy(negotiation) == 'admin'
            ? DealStatusKind.newPrice
            : DealStatusKind.yourCounter;
      case 'accepted':
        return DealStatusKind.acceptedOrderPending;
      case 'converted':
        return DealStatusKind.orderCreated;
      case 'rejected':
        return DealStatusKind.declined;
      case 'expired':
        return DealStatusKind.expired;
      default:
        return DealStatusKind.unknown;
    }
  }

  /// Sentence-case label for [statusKind] ("New Price Received"), never an
  /// all-caps pill. Without [l10n] the English label is returned.
  static String statusLabel(
    Map<String, dynamic> negotiation, {
    AppLocalizations? l10n,
  }) {
    final text = l10n ?? lookupAppLocalizations(const Locale('en'));
    switch (statusKind(negotiation)) {
      case DealStatusKind.requested:
        return text.dealStatusRequirementSent;
      case DealStatusKind.newPrice:
        return text.dealStatusNewPriceReceived;
      case DealStatusKind.yourCounter:
        return text.dealStatusYourCounterOffer;
      case DealStatusKind.acceptedOrderPending:
        return text.statusDealAcceptedOrderPending;
      case DealStatusKind.orderCreated:
        return text.statusDealOrderCreated;
      case DealStatusKind.declined:
        return text.dealStatusRequirementDeclined;
      case DealStatusKind.expired:
        return text.dealStatusRequirementExpired;
      case DealStatusKind.unknown:
        return _status(negotiation);
    }
  }

  /// The one action an inbox row offers, matching the Deal Desk list rules:
  /// respond to a new price, proceed to order (legacy accepted deals), or a
  /// passive state. With [orderShortcut] a deal with an order offers
  /// "View Order" first (the standalone Negotiations screen does this).
  static DealTileAction tileAction(
    Map<String, dynamic> negotiation, {
    bool orderShortcut = false,
  }) {
    final status = _status(negotiation);
    if (orderShortcut &&
        (hasLinkedOrder(negotiation) || status == 'converted')) {
      return DealTileAction.viewOrder;
    }
    if (needsReply(negotiation)) return DealTileAction.respond;
    switch (status) {
      case 'pending':
        return DealTileAction.underReview;
      case 'rejected':
        return DealTileAction.declined;
      case 'expired':
        return DealTileAction.expired;
      default:
        return DealTileAction.viewDetails;
    }
  }

  /// Position in the Requested → Price talk → Agreed → Order stepper, or -1
  /// for a declined/expired deal.
  static int stepIndex(Map<String, dynamic> negotiation) {
    switch (statusKind(negotiation)) {
      case DealStatusKind.requested:
        return 0;
      case DealStatusKind.newPrice:
      case DealStatusKind.yourCounter:
        return 1;
      case DealStatusKind.acceptedOrderPending:
        return 2;
      case DealStatusKind.orderCreated:
        return 3;
      case DealStatusKind.declined:
      case DealStatusKind.expired:
      case DealStatusKind.unknown:
        return -1;
    }
  }

  /// Latest per-unit price sent by [by] ('admin' or 'wholesaler'), read from
  /// the deal's history, then from its current offer. Null when [by] has not
  /// quoted a price yet.
  static num? latestPriceBy(Map<String, dynamic> negotiation, String by) {
    final history = negotiation['history'];
    if (history is List) {
      for (final entry in history.reversed) {
        if (entry is! Map) continue;
        if (entry['by']?.toString() != by) continue;
        if (entry['action']?.toString() == 'message') continue;
        final price = _num(entry['pricePerUnit']);
        if (price != null) return price;
      }
    }
    if (_offerBy(negotiation) == by) {
      return _num(negotiation['currentPricePerUnit']);
    }
    if (by == 'wholesaler') return _num(negotiation['requestedPricePerUnit']);
    return null;
  }

  static num? _num(dynamic value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '');

  /// "₹18,500".
  static String rupees(dynamic value) =>
      '₹${NumberFormatter.formatPrice(value ?? 0)}';

  /// Price suffix for a product snapshot: "/pc", "/m" or "/unit".
  static String unitSuffix(
    Map<dynamic, dynamic>? product,
    AppLocalizations l10n,
  ) {
    if (product == null) return l10n.commonPerUnit;
    final info = packInfoOf(product);
    if (info.isPack) {
      return info.contentUnit == ContentUnit.meter
          ? l10n.uiPerMeter
          : l10n.uiPerPiece;
    }
    return isMeterProduct(product) ? l10n.uiPerMeter : l10n.commonPerUnit;
  }

  /// Whole number of units in a deal.
  static int quantityOf(Map<String, dynamic> negotiation) =>
      int.tryParse(
        NumberFormatter.formatQuantity(negotiation['requestedQuantity']),
      ) ??
      0;
}

enum DealOrderStatus { orderCreated, acceptedOrderPending }

/// What the wholesaler sees as a deal's status (see
/// [DealDeskPresentation.statusKind]).
enum DealStatusKind {
  requested,
  newPrice,
  yourCounter,
  acceptedOrderPending,
  orderCreated,
  declined,
  expired,
  unknown,
}

/// The action shown on a Deal Desk inbox row (see
/// [DealDeskPresentation.tileAction]). [underReview], [declined] and
/// [expired] are passive: nothing to tap.
enum DealTileAction {
  respond,
  viewOrder,
  viewDetails,
  underReview,
  declined,
  expired,
}
