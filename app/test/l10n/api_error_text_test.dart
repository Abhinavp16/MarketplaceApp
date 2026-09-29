import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/l10n/api_error_text.dart';
import 'package:tradehub_demo/l10n/generated/app_localizations.dart';

DioException _error(Object? body, {int status = 400}) {
  final options = RequestOptions(path: '/orders');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: body),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final hi = lookupAppLocalizations(const Locale('hi'));

  test('maps nested and top-level backend codes', () {
    expect(
      apiErrorTextFor(
        hi,
        _error({
          'success': false,
          'message': 'Cart is empty',
          'error': {'code': 'CART_EMPTY'},
        }),
        isHindi: true,
      ),
      hi.apiErrorCartEmpty,
    );
    expect(
      apiErrorTextFor(
        en,
        _error({
          'success': false,
          'message': 'Only 2 units of Pump available',
          'code': 'INSUFFICIENT_STOCK',
        }),
      ),
      en.apiErrorInsufficientStock,
    );
  });

  test('keeps the amount from coupon minimum messages', () {
    expect(
      apiErrorTextFor(
        hi,
        _error({
          'message': 'Minimum purchase amount for this coupon is ₹1,500',
          'error': {'code': 'COUPON_MIN_PURCHASE_NOT_MET'},
        }),
        isHindi: true,
      ),
      hi.apiErrorCouponMinPurchaseAmount('1,500'),
    );
  });

  test('unknown codes use the server message in English only', () {
    final error = _error({
      'message': 'Something specific happened',
      'error': {'code': 'SOMETHING_NEW'},
    });
    expect(apiErrorTextFor(en, error), 'Something specific happened');
    expect(
      apiErrorTextFor(hi, error, isHindi: true, fallback: 'फ़ॉलबैक'),
      'फ़ॉलबैक',
    );
    expect(
      apiErrorTextFor(hi, error, isHindi: true),
      hi.commonSomethingWentWrong,
    );
  });

  test('connection problems show the network message', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/orders'),
      type: DioExceptionType.connectionError,
    );
    expect(apiErrorTextFor(en, error), en.commonNetworkError);
  });

  test('non-network errors use the fallback', () {
    expect(apiErrorTextFor(en, StateError('x'), fallback: 'F'), 'F');
    expect(apiErrorTextFor(en, StateError('x')), en.commonSomethingWentWrong);
  });
}
