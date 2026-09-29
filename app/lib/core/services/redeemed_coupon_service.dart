import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RedeemedCoupon {
  final String code;
  final String title;
  final String rule;
  final int redeemedAt;

  const RedeemedCoupon({
    required this.code,
    required this.title,
    required this.rule,
    required this.redeemedAt,
  });

  factory RedeemedCoupon.fromJson(Map<String, dynamic> json) {
    return RedeemedCoupon(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      rule: json['rule']?.toString() ?? '',
      redeemedAt: (json['redeemedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'title': title,
      'rule': rule,
      'redeemedAt': redeemedAt,
    };
  }
}

class RedeemedCouponService {
  static const _legacyKey = 'redeemed_coupons';

  static String _keyForUser(String userKey) {
    final safe = userKey.trim().isEmpty
        ? 'guest'
        : userKey.trim().toLowerCase().replaceAll(' ', '_');
    return 'redeemed_coupons_$safe';
  }

  static Future<List<RedeemedCoupon>> getCoupons({
    required String userKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyForUser(userKey);
    var raw = prefs.getString(key);

    // Backward compatibility: migrate legacy coupons once to the active user key.
    if ((raw == null || raw.isEmpty)) {
      final legacyRaw = prefs.getString(_legacyKey);
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        await prefs.setString(key, legacyRaw);
        await prefs.remove(_legacyKey);
        raw = legacyRaw;
      }
    }
    if (raw == null || raw.isEmpty) return [];
    final parsed = jsonDecode(raw);
    if (parsed is! List) return [];
    return parsed
        .whereType<Map>()
        .map((e) => RedeemedCoupon.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.redeemedAt.compareTo(a.redeemedAt));
  }

  static Future<void> redeemCoupon({
    required String userKey,
    required String code,
    required String title,
    required String rule,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) return;

    final current = await getCoupons(userKey: userKey);
    final exists = current.any((c) => c.code == normalizedCode);
    if (!exists) {
      current.insert(
        0,
        RedeemedCoupon(
          code: normalizedCode,
          title: title.trim(),
          rule: rule.trim(),
          redeemedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await _save(userKey: userKey, coupons: current);
    }
  }

  static Future<void> _save({
    required String userKey,
    required List<RedeemedCoupon> coupons,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyForUser(userKey),
      jsonEncode(coupons.map((c) => c.toJson()).toList()),
    );
  }

  static Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
      (key) => key == _legacyKey || key.startsWith('${_legacyKey}_'),
    );
    await Future.wait(keys.map(prefs.remove));
  }
}
