import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userDataKey = 'user_data';
  static const _isFirstLaunchKey = 'is_first_launch';
  static const _guestTrialStartedAtKey = 'guest_trial_started_at_ms';
  static const _guestAuthPromptLastShownAtKey =
      'guest_auth_prompt_last_shown_at_ms';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<void> _removeLegacyTokenKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
    ]);
  }

  // Token Management
  // Access and refresh tokens are intentionally kept only in platform secure
  // storage. Older SharedPreferences token copies are removed on save/clear.
  static Future<void> saveTokens(
    String accessToken,
    String refreshToken,
  ) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    await _removeLegacyTokenKeys();
  }

  static Future<String?> getAccessToken() {
    return _secureStorage.read(key: _accessTokenKey);
  }

  static Future<String?> getRefreshToken() {
    return _secureStorage.read(key: _refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    try {
      await Future.wait([
        _secureStorage.delete(key: _accessTokenKey),
        _secureStorage.delete(key: _refreshTokenKey),
      ]);
    } finally {
      await _removeLegacyTokenKeys();
    }
  }

  // User Data Management
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDataKey, jsonEncode(userData));
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_userDataKey);
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userDataKey);
  }

  // First Launch Check
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstLaunchKey) ?? true;
  }

  static Future<void> setFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLaunchKey, false);
  }

  // Guest Trial Management
  static Future<DateTime> getOrCreateGuestTrialStartedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMs = prefs.getInt(_guestTrialStartedAtKey);
    if (storedMs != null) {
      return DateTime.fromMillisecondsSinceEpoch(storedMs);
    }

    final now = DateTime.now();
    await prefs.setInt(_guestTrialStartedAtKey, now.millisecondsSinceEpoch);
    return now;
  }

  static Future<DateTime?> getGuestAuthPromptLastShownAt() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMs = prefs.getInt(_guestAuthPromptLastShownAtKey);
    if (storedMs == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(storedMs);
  }

  static Future<void> setGuestAuthPromptLastShownAt(DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _guestAuthPromptLastShownAtKey,
      value.millisecondsSinceEpoch,
    );
  }

  // Clear All
  static Future<void> clearAll() async {
    try {
      await clearTokens();
    } finally {
      await clearUserData();
    }
  }
}
