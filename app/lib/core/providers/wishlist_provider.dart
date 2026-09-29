import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WishlistItem {
  final String productId;
  final String name;
  final String? image;
  final double price;
  final double? mrp;
  final String? category;
  final String? nameHindi;

  final String? blurHash;

  WishlistItem({
    required this.productId,
    required this.name,
    this.image,
    required this.price,
    this.mrp,
    this.category,
    this.nameHindi,
    this.blurHash,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'image': image,
    'price': price,
    'mrp': mrp,
    'category': category,
    'nameHindi': nameHindi,
    'blurHash': blurHash,
  };

  factory WishlistItem.fromJson(Map<String, dynamic> json) => WishlistItem(
    productId: json['productId'] ?? '',
    name: json['name'] ?? '',
    image: json['image'],
    price: (json['price'] ?? 0).toDouble(),
    mrp: json['mrp'] != null ? (json['mrp']).toDouble() : null,
    category: json['category'],
    nameHindi: json['nameHindi'],
    blurHash: json['blurHash'],
  );
}

class WishlistState {
  final List<WishlistItem> items;

  const WishlistState({this.items = const []});

  bool contains(String productId) => items.any((i) => i.productId == productId);

  WishlistState copyWith({List<WishlistItem>? items}) =>
      WishlistState(items: items ?? this.items);
}

class WishlistNotifier extends StateNotifier<WishlistState> {
  static const _storageKey = 'wishlist_items';

  WishlistNotifier() : super(const WishlistState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        state = WishlistState(
          items: list.map((e) => WishlistItem.fromJson(e)).toList(),
        );
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = state.items.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(json));
  }

  void toggle(WishlistItem item) {
    if (state.contains(item.productId)) {
      remove(item.productId);
    } else {
      add(item);
    }
  }

  void add(WishlistItem item) {
    if (state.contains(item.productId)) return;
    state = state.copyWith(items: [...state.items, item]);
    _save();
  }

  void remove(String productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.productId != productId).toList(),
    );
    _save();
  }

  void clear() {
    state = const WishlistState();
    _save();
  }
}

final wishlistProvider = StateNotifierProvider<WishlistNotifier, WishlistState>(
  (ref) => WishlistNotifier(),
);
