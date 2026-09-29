import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import 'l10n.dart';

/// User-facing text for a failed API call, in the current language.
///
/// Order of preference:
/// 1. A localized message for a known backend error `code`
///    (top-level `code` or `error.code` in the response body).
/// 2. The server's `message` (English UI: always; Hindi UI: only when the
///    server already sent Hindi text).
/// 3. [fallback], then a generic "something went wrong" message.
///
/// Connection problems (no response) show the network error message.
String apiErrorText(BuildContext context, Object error, {String? fallback}) {
  return apiErrorTextFor(
    context.l10n,
    error,
    isHindi: context.isHindi,
    fallback: fallback,
  );
}

/// Same as [apiErrorText] without a [BuildContext] (for tests / services).
String apiErrorTextFor(
  AppLocalizations l10n,
  Object error, {
  bool isHindi = false,
  String? fallback,
}) {
  if (error is! DioException) {
    return fallback ?? l10n.commonSomethingWentWrong;
  }

  final response = error.response;
  if (response == null) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return l10n.commonNetworkError;
      default:
        return fallback ?? l10n.commonSomethingWentWrong;
    }
  }

  final data = response.data;
  final body = data is Map ? data : null;
  final nested = body?['error'];
  final nestedMap = nested is Map ? nested : null;
  final code = (body?['code'] ?? nestedMap?['code'])?.toString().trim() ?? '';
  final serverMessage =
      (body?['message'] ?? nestedMap?['message'])?.toString().trim() ?? '';

  final mapped = apiErrorCodeText(l10n, code, serverMessage: serverMessage);
  if (mapped != null) return mapped;

  if (serverMessage.isNotEmpty &&
      (!isHindi || _devanagari.hasMatch(serverMessage))) {
    return serverMessage;
  }
  return fallback ?? l10n.commonSomethingWentWrong;
}

final _devanagari = RegExp('[ऀ-ॿ]');
final _rupeeAmount = RegExp(r'₹\s?([\d,]+(?:\.\d+)?)');

/// Localized text for a backend error [code], or null when the code is unknown.
String? apiErrorCodeText(
  AppLocalizations l10n,
  String code, {
  String serverMessage = '',
}) {
  switch (code) {
    case 'INSUFFICIENT_STOCK':
      return l10n.apiErrorInsufficientStock;
    case 'MIN_WHOLESALE_QUANTITY_NOT_MET':
      return l10n.apiErrorMinWholesaleQuantity;
    case 'CART_EMPTY':
    case 'CART_NOT_FOUND':
      return l10n.apiErrorCartEmpty;
    case 'PRODUCT_NOT_FOUND':
      return l10n.apiErrorProductNotFound;
    case 'INVALID_QUANTITY':
      return l10n.apiErrorInvalidQuantity;
    case 'NEGOTIATION_DISABLED':
      return l10n.apiErrorNegotiationDisabled;
    case 'NEGOTIATION_CHECKOUT_DISABLED':
      return l10n.apiErrorNegotiationCheckoutDisabled;
    case 'NEGOTIATION_NOT_FOUND':
      return l10n.apiErrorNegotiationNotFound;
    case 'NEGOTIATION_EXPIRED':
      return l10n.apiErrorNegotiationExpired;
    case 'ADDRESS_INCOMPLETE':
      return l10n.apiErrorAddressIncomplete;
    case 'ORDER_NOT_FOUND':
      return l10n.apiErrorOrderNotFound;
    case 'INVALID_COUPON':
      return l10n.apiErrorInvalidCoupon;
    case 'COUPON_NOT_APPLICABLE':
      return l10n.apiErrorCouponNotApplicable;
    case 'COUPON_MIN_PURCHASE_NOT_MET':
      final amount = _rupeeAmount.firstMatch(serverMessage)?.group(1);
      return amount == null
          ? l10n.apiErrorCouponMinPurchase
          : l10n.apiErrorCouponMinPurchaseAmount(amount);
    case 'LOGIN_REQUIRED_FOR_ORDERING':
    case 'LOGIN_REQUIRED_FOR_CART_CHECKOUT':
    case 'LOGIN_REQUIRED_FOR_CART_COUPON':
    case 'AUTH_REQUIRED':
    case 'AUTH_TOKEN_REQUIRED':
    case 'UNAUTHORIZED':
      return l10n.commonLoginRequired;
    case 'SESSION_EXPIRED':
    case 'TOKEN_EXPIRED':
    case 'INVALID_TOKEN':
      return l10n.apiErrorSessionExpired;
    case 'ACCOUNT_DEACTIVATED':
      return l10n.apiErrorAccountDeactivated;
    case 'FORBIDDEN':
    case 'INSUFFICIENT_PERMISSIONS':
      return l10n.apiErrorNoPermission;
    case 'RATE_LIMIT_EXCEEDED':
      return l10n.apiErrorTooManyRequests;
    case 'SERVICE_UNAVAILABLE':
      return l10n.apiErrorServiceUnavailable;
    case 'SERVER_ERROR':
      return l10n.commonSomethingWentWrong;
    default:
      return null;
  }
}
