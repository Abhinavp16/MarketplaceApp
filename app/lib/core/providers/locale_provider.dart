import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_fonts.dart';

/// The app language (English or Hindi). The choice is saved on the device and
/// sent to the backend so notifications arrive in the same language.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier([Locale? initial]) : super(initial ?? english) {
    AppFonts.hindi = state.languageCode == 'hi';
  }

  static const english = Locale('en');
  static const hindi = Locale('hi');
  static const supportedLocales = [english, hindi];
  static const _storageKey = 'app_language';

  bool get isHindi => state.languageCode == 'hi';

  /// Reads the saved language (before the app starts).
  static Future<Locale> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_storageKey) == 'hi' ? hindi : english;
    } catch (_) {
      return english;
    }
  }

  /// Whether the user has picked a language at least once.
  static Future<bool> hasSavedChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_storageKey);
    } catch (_) {
      return false;
    }
  }

  Future<void> setLocale(Locale locale) async {
    final next = locale.languageCode == 'hi' ? hindi : english;
    AppFonts.hindi = next.languageCode == 'hi';
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, next.languageCode);
    } catch (_) {}
    await syncWithServer();
  }

  Future<void> toggle() => setLocale(isHindi ? english : hindi);

  /// Saves the language on the user's account (for notifications). Silent
  /// when signed out or offline; retried after the next login.
  Future<void> syncWithServer() async {
    try {
      final token = await StorageService.getAccessToken();
      if (token == null) return;
      await ApiClient().put(
        '/auth/preferences',
        data: {'language': state.languageCode},
      );
    } catch (_) {}
  }
}
