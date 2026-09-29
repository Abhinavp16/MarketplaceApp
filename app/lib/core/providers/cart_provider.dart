import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../services/storage_service.dart';

class CartItem {
  final String productId;
  final String cartItemKey;
  final String name;
  final String? image;
  final String? nameHindi;
  final String? brand;
  final String? category;
  final int minWholesaleQuantity;
  final double price;
  final double? mrp;
  final int quantity;
  final int stock;
  final String? stockIssue;

  CartItem({
    required this.productId,
    required this.cartItemKey,
    required this.name,
    this.image,
    this.nameHindi,
    this.brand,
    this.category,
    this.minWholesaleQuantity = 1,
    required this.price,
    this.mrp,
    required this.quantity,
    this.stock = 0,
    this.stockIssue,
  });

  CartItem copyWith({
    int? quantity,
    int? stock,
    String? stockIssue,
    bool clearIssue = false,
  }) {
    return CartItem(
      productId: productId,
      cartItemKey: cartItemKey,
      name: name,
      image: image,
      nameHindi: nameHindi,
      brand: brand,
      category: category,
      minWholesaleQuantity: minWholesaleQuantity,
      price: price,
      mrp: mrp,
      quantity: quantity ?? this.quantity,
      stock: stock ?? this.stock,
      stockIssue: clearIssue ? null : (stockIssue ?? this.stockIssue),
    );
  }

  bool get hasStockIssue => stockIssue != null || quantity > stock;
  double get total => price * quantity;
}

class CartState {
  final List<CartItem> items;
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> stockIssues;

  CartState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.stockIssues = const [],
  });

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? stockIssues,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      stockIssues: stockIssues ?? this.stockIssues,
    );
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get deliveryFee => subtotal > 0 ? 50 : 0;
  double get grandTotal => subtotal + deliveryFee;
  bool get hasStockIssues => items.any((item) => item.hasStockIssue);
}

class CartNotifier extends StateNotifier<CartState> {
  final Dio _dio;

  // Debounce timers for quantity updates to prevent race conditions
  final Map<String, Timer> _quantityDebounceTimers = {};

  CartNotifier()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
        ),
      ),
      super(CartState());

  Future<Dio> get _authedDio async {
    final token = await StorageService.getAccessToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
    return _dio;
  }

  int _positiveInt(dynamic value) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : 1;
  }

  Future<void> fetchCart() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = await _authedDio;
      final response = await dio.get('/cart');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final items = _parseServerCart(response.data['data']);
        state = state.copyWith(items: items, isLoading: false);
      }
    } catch (e) {
      // If not authenticated or error, keep local state
      state = state.copyWith(isLoading: false);
    }
  }

  /// Parse server cart response data into local CartItem list
  List<CartItem> _parseServerCart(Map<String, dynamic> data) {
    final List<dynamic> rawItems = data['items'] ?? [];
    return rawItems.map<CartItem>((item) {
      final product = item['product'] as Map<String, dynamic>? ?? {};
      final productId = item['productId']?.toString() ?? '';
      return CartItem(
        productId: productId,
        cartItemKey: item['cartItemKey']?.toString() ?? '$productId:default',
        name: product['name']?.toString() ?? '',
        nameHindi: product['nameHindi']?.toString(),
        brand: product['brand']?.toString(),
        category: product['category']?.toString(),
        minWholesaleQuantity: _positiveInt(product['minWholesaleQuantity']),
        image: product['image']?.toString(),
        price: (item['currentPrice'] ?? product['price'] ?? 0).toDouble(),
        // Keep MRP so the crossed-out price and % off survive cart sync.
        mrp: (product['mrp'] as num?)?.toDouble(),
        quantity: item['quantity'] ?? 1,
        stock: product['stock'] ?? 0,
      );
    }).toList();
  }

  Future<bool> addItem({
    required String productId,
    required String name,
    String? nameHindi,
    String? brand,
    String? category,
    int minWholesaleQuantity = 1,
    String? image,
    required double price,
    double? mrp,
    required int quantity,
    int stock = 99,
  }) async {
    final itemKey = '$productId:default';
    // Optimistic local update for instant UI feedback
    final existingIndex = state.items.indexWhere(
      (i) => i.cartItemKey == itemKey,
    );
    final updatedItems = List<CartItem>.from(state.items);

    if (existingIndex >= 0) {
      final existing = updatedItems[existingIndex];
      updatedItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      updatedItems.add(
        CartItem(
          productId: productId,
          cartItemKey: itemKey,
          name: name,
          nameHindi: nameHindi,
          brand: brand,
          category: category,
          minWholesaleQuantity: _positiveInt(minWholesaleQuantity),
          image: image,
          price: price,
          mrp: mrp,
          quantity: quantity,
          stock: stock,
        ),
      );
    }
    state = state.copyWith(items: updatedItems);

    // Sync with backend — use server response as source of truth
    try {
      final dio = await _authedDio;
      final response = await dio.post(
        '/cart/items',
        data: {'productId': productId, 'quantity': quantity},
      );
      if (response.data?['data'] != null) {
        final serverItems = _parseServerCart(response.data['data']);
        state = state.copyWith(items: serverItems);
      }
    } catch (_) {
      // Offline or not authenticated — keep optimistic state
    }
    return true;
  }

  Future<String?> updateQuantity(
    String productId,
    int quantity, {
    String? variantId,
  }) async {
    final itemKey = '$productId:default';
    if (quantity < 1) {
      // Cancel any pending debounce and remove item
      _quantityDebounceTimers[itemKey]?.cancel();
      _quantityDebounceTimers.remove(itemKey);
      removeItem(productId);
      return null;
    }

    // Check local stock limit first
    final item = state.items.firstWhere(
      (i) => i.cartItemKey == itemKey,
      orElse: () => state.items.first,
    );
    if (item.stock > 0 && quantity > item.stock) {
      return 'Only ${item.stock} available';
    }

    // Optimistic local update - always apply immediately
    final updatedItems = state.items.map((i) {
      if (i.cartItemKey == itemKey) {
        return i.copyWith(quantity: quantity, clearIssue: true);
      }
      return i;
    }).toList();
    state = state.copyWith(items: updatedItems);

    // Cancel any pending debounce timer for this product
    _quantityDebounceTimers[itemKey]?.cancel();

    // Debounce the API call - wait 500ms before sending to backend
    // This prevents race conditions from rapid clicks
    _quantityDebounceTimers[itemKey] = Timer(
      const Duration(milliseconds: 500),
      () async {
        await _syncQuantityToBackend(productId, quantity);
      },
    );

    return null;
  }

  // Separate method to sync quantity to backend (called after debounce)
  Future<void> _syncQuantityToBackend(String productId, int quantity) async {
    final itemKey = '$productId:default';
    // Find current quantity from state (may have changed since debounce started)
    final currentItem = state.items.firstWhere(
      (i) => i.cartItemKey == itemKey,
      orElse: () => state.items.first,
    );

    // Skip if quantity changed since we started debounce
    if (currentItem.quantity != quantity) return;

    try {
      final dio = await _authedDio;
      final response = await dio.put(
        '/cart/items/$productId',
        data: {'quantity': quantity},
      );
      if (response.data?['data'] != null) {
        final serverItems = _parseServerCart(response.data['data']);
        state = state.copyWith(items: serverItems);
      }
    } on DioException catch (e) {
      // Only handle stock errors - other errors silently fail (local state is already updated)
      final msg = e.response?.data?['message']?.toString();
      if (msg != null && msg.contains('Insufficient stock')) {
        // Revert to previous quantity
        final reverted = state.items.map((i) {
          if (i.cartItemKey == itemKey) {
            return i.copyWith(
              quantity: currentItem.quantity,
              stockIssue: 'Only ${currentItem.stock} available',
            );
          }
          return i;
        }).toList();
        state = state.copyWith(items: reverted);
      }
    }
  }

  Future<Map<String, dynamic>> validateStock() async {
    try {
      final dio = await _authedDio;
      final response = await dio.post('/cart/validate');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final bool valid = data['valid'] ?? true;
        final List<dynamic> rawIssues = data['issues'] ?? [];
        final issues = rawIssues
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();

        if (!valid) {
          // Update cart items with stock issues
          final issueMap = <String, Map<String, dynamic>>{};
          for (final issue in issues) {
            final key =
                issue['cartItemKey']?.toString() ??
                '${issue['productId']}:${issue['variantId'] ?? 'default'}';
            issueMap[key] = issue;
          }
          final updatedItems = state.items.map((item) {
            final issue = issueMap[item.cartItemKey];
            if (issue != null) {
              final availStock = (issue['availableStock'] ?? 0) as int;
              return item.copyWith(
                stock: availStock,
                stockIssue: issue['message']?.toString(),
              );
            }
            return item.copyWith(clearIssue: true);
          }).toList();
          state = state.copyWith(items: updatedItems, stockIssues: issues);
        } else {
          // Clear all stock issues
          final clearedItems = state.items
              .map((item) => item.copyWith(clearIssue: true))
              .toList();
          state = state.copyWith(items: clearedItems, stockIssues: []);
        }

        return {'valid': valid, 'issues': issues};
      }
    } catch (e) {
      // If validation fails, allow checkout (server will catch it)
    }
    return {'valid': true, 'issues': []};
  }

  Future<void> removeItem(String productId, {String? variantId}) async {
    final itemKey = '$productId:default';
    final updatedItems = state.items
        .where((i) => i.cartItemKey != itemKey)
        .toList();
    state = state.copyWith(items: updatedItems);

    // Sync with backend — use server response as source of truth
    try {
      final dio = await _authedDio;
      final response = await dio.delete('/cart/items/$productId');
      if (response.data?['data'] != null) {
        final serverItems = _parseServerCart(response.data['data']);
        state = state.copyWith(items: serverItems);
      }
    } catch (_) {}
  }

  Future<void> clearCart() async {
    state = state.copyWith(items: []);
    try {
      final dio = await _authedDio;
      await dio.delete('/cart');
    } catch (_) {}
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
