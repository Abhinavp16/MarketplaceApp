import 'dart:convert';
import 'dart:typed_data';

import 'package:demomart_demo/core/providers/cart_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal fake server: remembers one cart per run and records every call.
class _FakeServer implements HttpClientAdapter {
  final List<String> calls = [];
  final List<Map<String, dynamic>> cartItems = [];
  bool signedIn = false;
  int addStatus = 200;

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  Map<String, dynamic> get _cartBody => {
    'success': true,
    'data': {'items': List<Map<String, dynamic>>.from(cartItems)},
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');
    if (options.headers['Authorization'] == null) {
      return _json({'success': false}, 401);
    }
    if (options.method == 'POST' && options.path == '/cart/items') {
      if (addStatus != 200) return _json({'success': false}, addStatus);
      final data = options.data as Map;
      cartItems.add({
        'productId': data['productId'],
        'cartItemKey': '${data['productId']}:default',
        'quantity': data['quantity'],
        'currentPrice': 100,
        'product': {'name': 'Hammer', 'stock': 50, 'price': 100},
      });
      return _json(_cartBody, 200);
    }
    if (options.method == 'GET' && options.path == '/cart') {
      return _json(_cartBody, 200);
    }
    return _json({'success': true}, 200);
  }

  @override
  void close({bool force = false}) {}
}

CartNotifier _cart(_FakeServer server, {required bool Function() signedIn}) {
  return CartNotifier(
    dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
      ..httpClientAdapter = server,
    readToken: () async => signedIn() ? 'token' : null,
  );
}

Future<void> _addHammer(CartNotifier cart, {int quantity = 3}) {
  return cart.addItem(
    productId: 'p1',
    name: 'Hammer',
    price: 100,
    quantity: quantity,
  );
}

void main() {
  test('items added as a guest are still there after signing in', () async {
    final server = _FakeServer();
    var signedIn = false;
    final cart = _cart(server, signedIn: () => signedIn);

    await _addHammer(cart);
    expect(cart.state.items, hasLength(1), reason: 'kept locally as a guest');
    expect(server.cartItems, isEmpty, reason: 'the server refused the guest');

    signedIn = true;
    await cart.fetchCart();

    expect(cart.state.items, hasLength(1));
    expect(cart.state.items.single.productId, 'p1');
    expect(cart.state.items.single.quantity, 3);
    expect(server.cartItems, hasLength(1), reason: 'now in the account cart');
  });

  test('two screens refreshing at once send guest items only once', () async {
    final server = _FakeServer();
    var signedIn = false;
    final cart = _cart(server, signedIn: () => signedIn);

    await _addHammer(cart, quantity: 2);
    signedIn = true;
    await Future.wait([cart.fetchCart(), cart.fetchCart(), cart.fetchCart()]);

    expect(
      server.calls.where((c) => c == 'POST /cart/items').length,
      2,
      reason: 'one refused guest attempt plus exactly one send after sign-in',
    );
    expect(cart.state.items.single.quantity, 2, reason: 'not doubled');
  });

  test('a second refresh does not send the items again', () async {
    final server = _FakeServer();
    var signedIn = false;
    final cart = _cart(server, signedIn: () => signedIn);

    await _addHammer(cart);
    signedIn = true;
    await cart.fetchCart();
    await cart.fetchCart();

    expect(server.cartItems, hasLength(1));
    expect(cart.state.items.single.quantity, 3);
  });

  test(
    'items the account cannot take are dropped, not retried forever',
    () async {
      final server = _FakeServer();
      var signedIn = false;
      final cart = _cart(server, signedIn: () => signedIn);

      await _addHammer(cart);
      signedIn = true;
      server.addStatus = 400; // e.g. below the dealer minimum quantity
      await cart.fetchCart();
      expect(cart.state.items, isEmpty);

      server.addStatus = 200;
      await cart.fetchCart();
      expect(server.cartItems, isEmpty, reason: 'not sent again');
    },
  );

  test('a signed-in add still goes straight to the server', () async {
    final server = _FakeServer();
    final cart = _cart(server, signedIn: () => true);

    await _addHammer(cart);
    await cart.fetchCart();

    expect(server.cartItems, hasLength(1));
    expect(cart.state.items.single.quantity, 3);
    expect(
      server.calls.where((c) => c == 'POST /cart/items').length,
      1,
      reason: 'no duplicate send',
    );
  });
}
